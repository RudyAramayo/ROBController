//
//  RPLidarMapView.swift
//  ROBController
//
//  Created by Rob Makina on 7/27/25.
//  Copyright © 2025 OrbitusRobotics. All rights reserved.
//

import Foundation
import MapKit
import UIKit

@objc(ROBOpenStreetMapViewDelegate)
public protocol ROBOpenStreetMapViewDelegate: NSObjectProtocol {
    func openStreetMapViewDidRequestSearch(_ mapView: ROBOpenStreetMapView)

    func openStreetMapView(
        _ mapView: ROBOpenStreetMapView,
        didSelectDestinationLatitude latitude: Double,
        longitude: Double
    )
}

private enum ROBBaseMapStyle: String, CaseIterable {
    case navigation
    case terrain
    case satellite

    var title: String {
        switch self {
        case .navigation: return "Navigation"
        case .terrain: return "Terrain"
        case .satellite: return "Satellite"
        }
    }

    var attribution: String? {
        switch self {
        case .navigation:
            return "© OpenStreetMap contributors"
        case .terrain:
            return "Map © OpenStreetMap • Style © OpenTopoMap"
        case .satellite:
            return nil
        }
    }

    var tileURLTemplate: String? {
        switch self {
        case .navigation:
            return "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        case .terrain:
            return "https://tile.opentopomap.org/{z}/{x}/{y}.png"
        case .satellite:
            return nil
        }
    }
}

private enum ROBBaseMapStyleStore {
    private static let key = "ROBController.OpenStreetMap.BaseMapStyle.v1"

    static func load(defaults: UserDefaults = .standard) -> ROBBaseMapStyle {
        defaults.string(forKey: key).flatMap(ROBBaseMapStyle.init(rawValue:))
            ?? .navigation
    }

    static func save(_ style: ROBBaseMapStyle, defaults: UserDefaults = .standard) {
        defaults.set(style.rawValue, forKey: key)
    }
}

private struct ROBLidarOverlayCalibration {
    static let defaultScale = 0.90
    static let `default` = ROBLidarOverlayCalibration(scale: defaultScale, northRotationDegrees: 0)

    let scale: Double
    let northRotationDegrees: Double

    init(scale: Double, northRotationDegrees: Double) {
        self.scale = min(max(scale.isFinite ? scale : Self.defaultScale, 0.50), 1.50)
        var rotation = (northRotationDegrees.isFinite ? northRotationDegrees : 0)
            .truncatingRemainder(dividingBy: 360)
        if rotation >= 180 { rotation -= 360 }
        if rotation < -180 { rotation += 360 }
        self.northRotationDegrees = rotation
    }

    var northRotationRadians: Double {
        northRotationDegrees * .pi / 180
    }
}

private enum ROBLidarOverlayCalibrationStore {
    private static let scaleKey = "ROBController.OpenStreetMap.OverlayScale.v1"
    private static let rotationKey = "ROBController.OpenStreetMap.NorthRotationDegrees.v1"

    static func load(defaults: UserDefaults = .standard) -> ROBLidarOverlayCalibration {
        let scale = defaults.object(forKey: scaleKey) == nil
            ? ROBLidarOverlayCalibration.default.scale
            : defaults.double(forKey: scaleKey)
        let rotation = defaults.object(forKey: rotationKey) == nil
            ? ROBLidarOverlayCalibration.default.northRotationDegrees
            : defaults.double(forKey: rotationKey)
        return ROBLidarOverlayCalibration(scale: scale, northRotationDegrees: rotation)
    }

    static func save(
        _ calibration: ROBLidarOverlayCalibration,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(calibration.scale, forKey: scaleKey)
        defaults.set(calibration.northRotationDegrees, forKey: rotationKey)
    }
}

private struct ROBLidarLocationOffset: Equatable {
    private static let maximumAbsoluteMeters = 5_000.0

    let eastMeters: Double
    let northMeters: Double

    init(eastMeters: Double, northMeters: Double) {
        self.eastMeters = min(max(eastMeters.isFinite ? eastMeters : 0, -Self.maximumAbsoluteMeters), Self.maximumAbsoluteMeters)
        self.northMeters = min(max(northMeters.isFinite ? northMeters : 0, -Self.maximumAbsoluteMeters), Self.maximumAbsoluteMeters)
    }

    static let zero = ROBLidarLocationOffset(eastMeters: 0, northMeters: 0)

    var isAdjusted: Bool {
        abs(eastMeters) >= 0.05 || abs(northMeters) >= 0.05
    }
}

private enum ROBLidarLocationOffsetStore {
    private static let eastKey = "ROBController.OpenStreetMap.LocationOffsetEastMeters.v1"
    private static let northKey = "ROBController.OpenStreetMap.LocationOffsetNorthMeters.v1"

    static func load(defaults: UserDefaults = .standard) -> ROBLidarLocationOffset {
        ROBLidarLocationOffset(
            eastMeters: defaults.double(forKey: eastKey),
            northMeters: defaults.double(forKey: northKey)
        )
    }

    static func save(
        _ offset: ROBLidarLocationOffset,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(offset.eastMeters, forKey: eastKey)
        defaults.set(offset.northMeters, forKey: northKey)
    }
}

/// An OpenStreetMap-backed navigation surface which keeps ROB's local lidar
/// frame registered to the robot's current geographic position. At street
/// level the scan and occupancy image become readable; when zoomed out the map
/// remains useful for picking a navigation destination.
@objc(ROBOpenStreetMapView)
public final class ROBOpenStreetMapView: UIView, MKMapViewDelegate, UIGestureRecognizerDelegate {
    private static let closestCameraDistance: CLLocationDistance = 1

    @objc public weak var mapDelegate: ROBOpenStreetMapViewDelegate?

    private let mapView = MKMapView(frame: .zero)
    private let lidarView = ROBLidarGeographicOverlayView(frame: .zero)
    private let recenterButton = UIButton(type: .system)
    private let searchButton = UIButton(type: .system)
    private let mapStyleButton = UIButton(type: .system)
    private let instructionLabel = UILabel(frame: .zero)
    private let attributionLabel = UILabel(frame: .zero)
    private let scanStatusLabel = UILabel(frame: .zero)
    private let robotAnnotation = MKPointAnnotation()
    private let destinationAnnotation = MKPointAnnotation()
    private var rawRobotCoordinate: CLLocationCoordinate2D?
    private var robotCoordinate: CLLocationCoordinate2D?
    private var pendingPerceivedRobotCoordinate: CLLocationCoordinate2D?
    private var hasCenteredOnRobot = false
    private var lidarReturnCount = 0
    private var hasOccupancyMap = false
    private var baseMapStyle = ROBBaseMapStyleStore.load()
    private var baseTileOverlay: MKTileOverlay?
    private var overlayCalibration = ROBLidarOverlayCalibrationStore.load()
    private var locationOffset = ROBLidarLocationOffsetStore.load()
    private var pendingStyleCamera: MKMapCamera?
    private var styleCameraRestoreGeneration = 0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUpMap()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpMap()
    }

    private func setUpMap() {
        backgroundColor = UIColor(red: 0.02, green: 0.027, blue: 0.031, alpha: 1)
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0.94, green: 0.66, blue: 0.25, alpha: 0.3).cgColor

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.pointOfInterestFilter = .excludingAll
        enableClosestMapZoom()
        addSubview(mapView)

        applyBaseMapStyle(baseMapStyle, persist: false)

        lidarView.translatesAutoresizingMaskIntoConstraints = false
        lidarView.isUserInteractionEnabled = false
        lidarView.mapView = mapView
        lidarView.calibration = overlayCalibration
        addSubview(lidarView)

        configureMapButton(
            searchButton,
            title: "Search destination",
            symbol: "magnifyingglass",
            action: #selector(searchPressed)
        )
        configureMapButton(
            recenterButton,
            title: "Recenter ROB",
            symbol: "location.fill",
            action: #selector(recenterPressed)
        )
        configureMapButton(
            mapStyleButton,
            title: "",
            symbol: "map.fill",
            action: #selector(mapStylePressed)
        )
        mapStyleButton.accessibilityLabel = "Map and lidar settings"
        mapStyleButton.showsMenuAsPrimaryAction = true
        rebuildMapSettingsMenu()

        scanStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        scanStatusLabel.text = "LIDAR / AWAITING LOCAL FRAME"
        scanStatusLabel.textAlignment = .center
        scanStatusLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        scanStatusLabel.textColor = UIColor(red: 0.94, green: 0.66, blue: 0.25, alpha: 1)
        scanStatusLabel.backgroundColor = UIColor(red: 0.02, green: 0.027, blue: 0.031, alpha: 0.84)
        scanStatusLabel.layer.borderWidth = 1
        scanStatusLabel.layer.borderColor = UIColor(red: 0.94, green: 0.66, blue: 0.25, alpha: 0.34).cgColor
        scanStatusLabel.layer.cornerRadius = 2
        scanStatusLabel.layer.masksToBounds = true
        addSubview(scanStatusLabel)

        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "Long-press ROB's actual position • Tap destination • Pinch to zoom"
        instructionLabel.textAlignment = .center
        instructionLabel.font = .preferredFont(forTextStyle: .caption1)
        instructionLabel.textColor = .white
        instructionLabel.backgroundColor = UIColor(red: 0.02, green: 0.027, blue: 0.031, alpha: 0.82)
        instructionLabel.layer.cornerRadius = 2
        instructionLabel.layer.masksToBounds = true
        instructionLabel.adjustsFontSizeToFitWidth = true
        instructionLabel.minimumScaleFactor = 0.75
        addSubview(instructionLabel)

        attributionLabel.translatesAutoresizingMaskIntoConstraints = false
        attributionLabel.text = baseMapStyle.attribution
        attributionLabel.isHidden = baseMapStyle.attribution == nil
        attributionLabel.font = .preferredFont(forTextStyle: .caption2)
        attributionLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        attributionLabel.backgroundColor = UIColor(red: 0.02, green: 0.027, blue: 0.031, alpha: 0.82)
        attributionLabel.layer.cornerRadius = 2
        attributionLabel.layer.masksToBounds = true
        addSubview(attributionLabel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        let locationPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(mapLocationPressed(_:))
        )
        locationPress.minimumPressDuration = 0.6
        locationPress.delegate = self
        tap.require(toFail: locationPress)
        mapView.addGestureRecognizer(tap)
        mapView.addGestureRecognizer(locationPress)

        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mapView.topAnchor.constraint(equalTo: topAnchor),
            mapView.bottomAnchor.constraint(equalTo: bottomAnchor),

            lidarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lidarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            lidarView.topAnchor.constraint(equalTo: topAnchor),
            lidarView.bottomAnchor.constraint(equalTo: bottomAnchor),

            searchButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 12),
            searchButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            searchButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 42),

            recenterButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -12),
            recenterButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            recenterButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 42),

            mapStyleButton.trailingAnchor.constraint(
                equalTo: recenterButton.leadingAnchor,
                constant: -8
            ),
            mapStyleButton.topAnchor.constraint(equalTo: recenterButton.topAnchor),
            mapStyleButton.widthAnchor.constraint(equalToConstant: 44),
            mapStyleButton.heightAnchor.constraint(equalTo: recenterButton.heightAnchor),

            scanStatusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            scanStatusLabel.topAnchor.constraint(equalTo: searchButton.bottomAnchor, constant: 6),
            scanStatusLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.72),
            scanStatusLabel.heightAnchor.constraint(equalToConstant: 30),

            instructionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            instructionLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            instructionLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.9),
            instructionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),

            attributionLabel.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -6),
            attributionLabel.bottomAnchor.constraint(equalTo: instructionLabel.topAnchor, constant: -6)
        ])

        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
        )
        mapView.setRegion(initialRegion, animated: false)
    }

    private func configureMapButton(
        _ button: UIButton,
        title: String,
        symbol: String,
        action: Selector
    ) {
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.imagePadding = 7
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = 2
        configuration.baseBackgroundColor = UIColor(red: 0.02, green: 0.027, blue: 0.031, alpha: 0.9)
        configuration.baseForegroundColor = UIColor(red: 0.94, green: 0.66, blue: 0.25, alpha: 1)
        configuration.background.strokeColor = UIColor(red: 0.94, green: 0.66, blue: 0.25, alpha: 0.42)
        configuration.background.strokeWidth = 1
        button.configuration = configuration
        button.addTarget(self, action: action, for: .touchUpInside)
        addSubview(button)
    }

    private func rebuildMapSettingsMenu() {
        let baseMapMenu = UIMenu(
            title: "Base Map",
            children: ROBBaseMapStyle.allCases.map { style in
                UIAction(
                    title: style.title,
                    state: style == baseMapStyle ? .on : .off
                ) { [weak self] _ in
                    self?.applyBaseMapStyle(style, persist: true)
                }
            }
        )
        let scaleValues = [0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 1.10, 1.25]
        let scaleMenu = UIMenu(
            title: String(
                format: "Overlay Scale — %d%%",
                Int((overlayCalibration.scale * 100).rounded())
            ),
            children: scaleValues.map { scale in
                UIAction(
                    title: String(format: "%d%%", Int((scale * 100).rounded())),
                    state: abs(scale - overlayCalibration.scale) < 0.005 ? .on : .off
                ) { [weak self] _ in
                    self?.setOverlayCalibration(
                        ROBLidarOverlayCalibration(
                            scale: scale,
                            northRotationDegrees: self?.overlayCalibration.northRotationDegrees ?? 0
                        )
                    )
                }
            }
        )
        let northMenu = UIMenu(
            title: String(
                format: "North Rotation — %+.0f°",
                overlayCalibration.northRotationDegrees
            ),
            children: [
                UIAction(title: "Rotate Left 5°", image: UIImage(systemName: "rotate.left")) {
                    [weak self] _ in self?.adjustNorthRotation(by: -5)
                },
                UIAction(title: "Rotate Right 5°", image: UIImage(systemName: "rotate.right")) {
                    [weak self] _ in self?.adjustNorthRotation(by: 5)
                },
                UIAction(title: "Reset North") { [weak self] _ in
                    guard let self else { return }
                    self.setOverlayCalibration(
                        ROBLidarOverlayCalibration(
                            scale: self.overlayCalibration.scale,
                            northRotationDegrees: 0
                        )
                    )
                }
            ]
        )
        let locationMenu = UIMenu(
            title: "ROB Location — \(locationAdjustmentDescription)",
            children: [
                UIAction(title: "Set ROB to Map Center", image: UIImage(systemName: "scope")) {
                    [weak self] _ in self?.alignRobotToMapCenter()
                },
                UIAction(title: "Use Device GPS", image: UIImage(systemName: "location")) {
                    [weak self] _ in self?.resetPerceivedRobotLocation()
                }
            ]
        )
        mapStyleButton.menu = UIMenu(
            title: "Map Settings",
            children: [baseMapMenu, locationMenu, scaleMenu, northMenu]
        )
    }

    private func adjustNorthRotation(by degrees: Double) {
        setOverlayCalibration(
            ROBLidarOverlayCalibration(
                scale: overlayCalibration.scale,
                northRotationDegrees: overlayCalibration.northRotationDegrees + degrees
            )
        )
    }

    private func setOverlayCalibration(_ calibration: ROBLidarOverlayCalibration) {
        overlayCalibration = calibration
        ROBLidarOverlayCalibrationStore.save(calibration)
        lidarView.calibration = calibration
        refreshScanStatus()
        rebuildMapSettingsMenu()
        lidarView.setNeedsDisplay()
    }

    private func applyBaseMapStyle(_ style: ROBBaseMapStyle, persist: Bool) {
        let preservedCamera = persist ? mapView.camera.copy() as? MKMapCamera : nil
        if let baseTileOverlay {
            mapView.removeOverlay(baseTileOverlay)
        }
        baseMapStyle = style
        baseTileOverlay = nil
        mapView.mapType = style == .satellite ? .satellite : .standard
        enableClosestMapZoom()
        keepLidarOverlayVisible()
        if let template = style.tileURLTemplate {
            let overlay = MKTileOverlay(urlTemplate: template)
            overlay.tileSize = CGSize(width: 256, height: 256)
            overlay.minimumZ = 1
            overlay.maximumZ = style == .terrain ? 17 : 19
            overlay.canReplaceMapContent = true
            mapView.addOverlay(overlay, level: .aboveLabels)
            baseTileOverlay = overlay
        }
        attributionLabel.text = style.attribution
        attributionLabel.isHidden = style.attribution == nil
        if persist {
            ROBBaseMapStyleStore.save(style)
        }
        restoreCameraAfterStyleChange(preservedCamera)
        rebuildMapSettingsMenu()
        lidarView.setNeedsDisplay()
    }

    private func enableClosestMapZoom() {
        guard let zoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: Self.closestCameraDistance
        ) else { return }
        mapView.setCameraZoomRange(zoomRange, animated: false)
    }

    private func restoreCameraAfterStyleChange(_ camera: MKMapCamera?) {
        guard let camera else { return }
        styleCameraRestoreGeneration &+= 1
        let generation = styleCameraRestoreGeneration
        pendingStyleCamera = camera

        // MapKit can replace its renderer after mapType changes. Restore once
        // immediately and once on the next run loop after that replacement.
        mapView.setCamera(camera, animated: false)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  generation == self.styleCameraRestoreGeneration,
                  let pendingStyleCamera = self.pendingStyleCamera else { return }
            self.enableClosestMapZoom()
            self.mapView.setCamera(pendingStyleCamera, animated: false)
            self.pendingStyleCamera = nil
            self.keepLidarOverlayVisible()
        }
    }

    private func keepLidarOverlayVisible() {
        guard lidarView.superview === self else { return }
        lidarView.isHidden = false
        lidarView.alpha = 1
        insertSubview(lidarView, aboveSubview: mapView)
        lidarView.setNeedsDisplay()
    }

    @objc(updateRobotLatitude:longitude:)
    public func updateRobot(latitude: Double, longitude: Double) {
        let rawCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(rawCoordinate) else { return }
        rawRobotCoordinate = rawCoordinate
        if let pendingPerceivedRobotCoordinate {
            locationOffset = Self.locationOffset(
                from: rawCoordinate,
                to: pendingPerceivedRobotCoordinate
            )
            ROBLidarLocationOffsetStore.save(locationOffset)
            self.pendingPerceivedRobotCoordinate = nil
        }
        let coordinate = Self.coordinate(from: rawCoordinate, applying: locationOffset)
        displayRobot(at: coordinate)
        if !hasCenteredOnRobot {
            hasCenteredOnRobot = true
            recenter(animated: false)
        }
    }

    private func displayRobot(at coordinate: CLLocationCoordinate2D?) {
        robotCoordinate = coordinate
        guard let coordinate else {
            mapView.removeAnnotation(robotAnnotation)
            lidarView.robotCoordinate = nil
            refreshScanStatus()
            rebuildMapSettingsMenu()
            lidarView.setNeedsDisplay()
            return
        }
        robotAnnotation.coordinate = coordinate
        robotAnnotation.title = locationOffset.isAdjusted || pendingPerceivedRobotCoordinate != nil
            ? "ROB • Adjusted location"
            : "ROB"
        if !mapView.annotations.contains(where: { $0 === robotAnnotation }) {
            mapView.addAnnotation(robotAnnotation)
        }
        lidarView.robotCoordinate = coordinate
        refreshScanStatus()
        rebuildMapSettingsMenu()
        lidarView.setNeedsDisplay()
    }

    private func alignRobotToMapCenter() {
        setPerceivedRobotCoordinate(mapView.centerCoordinate)
    }

    private func resetPerceivedRobotLocation() {
        locationOffset = .zero
        pendingPerceivedRobotCoordinate = nil
        ROBLidarLocationOffsetStore.save(locationOffset)
        displayRobot(at: rawRobotCoordinate)
    }

    private var locationAdjustmentDescription: String {
        guard locationOffset.isAdjusted else {
            return pendingPerceivedRobotCoordinate == nil ? "Device GPS" : "Manual anchor"
        }
        return String(
            format: "E%+.1f m / N%+.1f m",
            locationOffset.eastMeters,
            locationOffset.northMeters
        )
    }

    private func setPerceivedRobotCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        if let rawRobotCoordinate {
            locationOffset = Self.locationOffset(from: rawRobotCoordinate, to: coordinate)
            pendingPerceivedRobotCoordinate = nil
            ROBLidarLocationOffsetStore.save(locationOffset)
        } else {
            pendingPerceivedRobotCoordinate = coordinate
        }
        displayRobot(at: coordinate)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private static func locationOffset(
        from source: CLLocationCoordinate2D,
        to target: CLLocationCoordinate2D
    ) -> ROBLidarLocationOffset {
        let averageLatitudeRadians = ((source.latitude + target.latitude) / 2) * .pi / 180
        let longitudeMeters = max(1, 111_320 * cos(averageLatitudeRadians))
        return ROBLidarLocationOffset(
            eastMeters: (target.longitude - source.longitude) * longitudeMeters,
            northMeters: (target.latitude - source.latitude) * 111_132
        )
    }

    private static func coordinate(
        from source: CLLocationCoordinate2D,
        applying offset: ROBLidarLocationOffset
    ) -> CLLocationCoordinate2D {
        let latitude = source.latitude + offset.northMeters / 111_132
        let longitudeMeters = max(1, 111_320 * cos(source.latitude * .pi / 180))
        return CLLocationCoordinate2D(
            latitude: latitude,
            longitude: source.longitude + offset.eastMeters / longitudeMeters
        )
    }

    @objc(updateLaserPoints:headingRadians:)
    public func updateLaserPoints(_ points: [String], headingRadians: Double) {
        lidarReturnCount = points.count
        refreshScanStatus()
        lidarView.update(points: points, headingRadians: headingRadians)
    }

    @objc(updateOccupancyMapImage:)
    public func updateOccupancyMapImage(_ image: UIImage?) {
        hasOccupancyMap = image != nil
        refreshScanStatus()
        lidarView.occupancyMapImage = image
        lidarView.setNeedsDisplay()
    }

    private func refreshScanStatus() {
        let gridState = hasOccupancyMap ? "GRID LIVE" : "NO GRID"
        let anchorState: String
        if locationOffset.isAdjusted || pendingPerceivedRobotCoordinate != nil {
            anchorState = "ADJUSTED"
        } else {
            anchorState = robotCoordinate == nil ? "MAP CENTER" : "GPS"
        }
        scanStatusLabel.text = String(
            format: "LIDAR / %04d / %@ / %@ / %d%% / N%+.0f°",
            lidarReturnCount,
            gridState,
            anchorState,
            Int((overlayCalibration.scale * 100).rounded()),
            overlayCalibration.northRotationDegrees
        )
    }

    @objc(showDestinationWithLatitude:longitude:title:)
    public func showDestination(latitude: Double, longitude: Double, title: String) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        destinationAnnotation.coordinate = coordinate
        destinationAnnotation.title = title
        if !mapView.annotations.contains(where: { $0 === destinationAnnotation }) {
            mapView.addAnnotation(destinationAnnotation)
        }
        mapView.selectAnnotation(destinationAnnotation, animated: true)
        mapView.setRegion(
            MKCoordinateRegion(center: coordinate, latitudinalMeters: 250, longitudinalMeters: 250),
            animated: true
        )
    }

    @objc public func recenter() {
        recenter(animated: true)
    }

    private func recenter(animated: Bool) {
        guard let coordinate = robotCoordinate else { return }
        mapView.setRegion(
            MKCoordinateRegion(center: coordinate, latitudinalMeters: 45, longitudinalMeters: 45),
            animated: animated
        )
    }

    @objc private func recenterPressed() {
        recenter(animated: true)
    }

    @objc private func searchPressed() {
        mapDelegate?.openStreetMapViewDidRequestSearch(self)
    }

    @objc private func mapStylePressed() {}

    @objc private func mapTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        let point = recognizer.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        destinationAnnotation.coordinate = coordinate
        destinationAnnotation.title = "Selected destination"
        if !mapView.annotations.contains(where: { $0 === destinationAnnotation }) {
            mapView.addAnnotation(destinationAnnotation)
        }
        mapView.selectAnnotation(destinationAnnotation, animated: true)
        mapDelegate?.openStreetMapView(
            self,
            didSelectDestinationLatitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    @objc private func mapLocationPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let point = recognizer.location(in: mapView)
        setPerceivedRobotCoordinate(mapView.convert(point, toCoordinateFrom: mapView))
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let touchedView = touch.view
        return touchedView !== searchButton && touchedView !== recenterButton
    }

    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        lidarView.setNeedsDisplay()
    }

    public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let tileOverlay = overlay as? MKTileOverlay else {
            return MKOverlayRenderer(overlay: overlay)
        }
        return MKTileOverlayRenderer(tileOverlay: tileOverlay)
    }

    public func mapView(
        _ mapView: MKMapView,
        viewFor annotation: MKAnnotation
    ) -> MKAnnotationView? {
        let identifier = annotation === robotAnnotation ? "robot" : "destination"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        view.annotation = annotation
        view.canShowCallout = true
        if annotation === robotAnnotation {
            view.markerTintColor = UIColor(red: 0.94, green: 0.66, blue: 0.25, alpha: 1)
            view.glyphImage = UIImage(systemName: "dot.radiowaves.left.and.right")
        } else {
            view.markerTintColor = .systemRed
            view.glyphImage = UIImage(systemName: "flag.fill")
        }
        return view
    }
}

private final class ROBLidarGeographicOverlayView: UIView {
    struct Sample {
        let distanceMeters: Double
        let angleRadians: Double
    }

    weak var mapView: MKMapView?
    var robotCoordinate: CLLocationCoordinate2D?
    var occupancyMapImage: UIImage?
    var calibration = ROBLidarOverlayCalibrationStore.load()
    private var samples: [Sample] = []
    private var headingRadians: Double = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        contentMode = .redraw
    }

    func update(points: [String], headingRadians: Double) {
        self.headingRadians = headingRadians.isFinite ? headingRadians : 0
        samples = points.compactMap { point in
            let fields = point.split(separator: ":", omittingEmptySubsequences: false)
            guard fields.count >= 2,
                  let distance = Double(fields[0]),
                  let angle = Double(fields[1]),
                  distance.isFinite,
                  angle.isFinite,
                  distance >= 0,
                  distance <= 100 else {
                return nil
            }
            return Sample(distanceMeters: distance, angleRadians: angle)
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let mapView,
              let robotCoordinate = drawingAnchorCoordinate(in: mapView),
              let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let center = mapView.convert(robotCoordinate, toPointTo: self)
        drawOccupancyMap(in: context, center: center, mapView: mapView, robotCoordinate: robotCoordinate)

        context.saveGState()
        let scanColor = UIColor(red: 0.94, green: 0.66, blue: 0.25, alpha: 0.96)
        context.setFillColor(scanColor.cgColor)
        context.setShadow(offset: .zero, blur: 2.5, color: scanColor.cgColor)
        for sample in samples {
            // RPLidar uses zero straight ahead. Rotate that local frame by ROB's
            // map heading before projecting metres into geographic coordinates.
            let theta = sample.angleRadians + headingRadians + calibration.northRotationRadians
            let calibratedDistance = sample.distanceMeters * calibration.scale
            let north = cos(theta) * calibratedDistance
            let east = sin(theta) * calibratedDistance
            let coordinate = offsetCoordinate(
                from: robotCoordinate,
                eastMeters: east,
                northMeters: north
            )
            let point = mapView.convert(coordinate, toPointTo: self)
            guard rect.insetBy(dx: -8, dy: -8).contains(point) else { continue }
            context.fillEllipse(in: CGRect(x: point.x - 2.2, y: point.y - 2.2, width: 4.4, height: 4.4))
        }
        context.restoreGState()

        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10))
    }

    private func drawingAnchorCoordinate(in mapView: MKMapView) -> CLLocationCoordinate2D? {
        if let robotCoordinate, CLLocationCoordinate2DIsValid(robotCoordinate) {
            return robotCoordinate
        }
        guard !samples.isEmpty || occupancyMapImage != nil else { return nil }
        let centerCoordinate = mapView.centerCoordinate
        return CLLocationCoordinate2DIsValid(centerCoordinate) ? centerCoordinate : nil
    }

    private func drawOccupancyMap(
        in context: CGContext,
        center: CGPoint,
        mapView: MKMapView,
        robotCoordinate: CLLocationCoordinate2D
    ) {
        guard let occupancyMapImage else { return }
        // The legacy occupancy payload does not include a map resolution or
        // origin. Keep its historical 20 m local window centered on ROB until
        // Cerebro starts publishing calibrated map metadata.
        let halfExtentMeters = 10 * calibration.scale
        let eastEdge = offsetCoordinate(
            from: robotCoordinate,
            eastMeters: halfExtentMeters,
            northMeters: 0
        )
        let northEdge = offsetCoordinate(
            from: robotCoordinate,
            eastMeters: 0,
            northMeters: halfExtentMeters
        )
        let eastPoint = mapView.convert(eastEdge, toPointTo: self)
        let northPoint = mapView.convert(northEdge, toPointTo: self)
        let halfWidth = abs(eastPoint.x - center.x)
        let halfHeight = abs(northPoint.y - center.y)
        guard halfWidth > 0.5, halfHeight > 0.5 else { return }

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(headingRadians + calibration.northRotationRadians))
        context.setAlpha(0.38)
        occupancyMapImage.draw(
            in: CGRect(x: -halfWidth, y: -halfHeight, width: halfWidth * 2, height: halfHeight * 2),
            blendMode: .normal,
            alpha: 0.75
        )
        context.restoreGState()
    }

    private func offsetCoordinate(
        from origin: CLLocationCoordinate2D,
        eastMeters: Double,
        northMeters: Double
    ) -> CLLocationCoordinate2D {
        let latitudeRadians = origin.latitude * .pi / 180
        let latitude = origin.latitude + northMeters / 111_132.0
        let longitudeScale = max(1.0, 111_320.0 * cos(latitudeRadians))
        let longitude = origin.longitude + eastMeters / longitudeScale
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
