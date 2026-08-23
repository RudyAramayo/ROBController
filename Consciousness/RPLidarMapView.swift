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

/// An OpenStreetMap-backed navigation surface which keeps ROB's local lidar
/// frame registered to the robot's current geographic position. At street
/// level the scan and occupancy image become readable; when zoomed out the map
/// remains useful for picking a navigation destination.
@objc(ROBOpenStreetMapView)
public final class ROBOpenStreetMapView: UIView, MKMapViewDelegate, UIGestureRecognizerDelegate {
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
    private var robotCoordinate: CLLocationCoordinate2D?
    private var hasCenteredOnRobot = false
    private var lidarReturnCount = 0
    private var hasOccupancyMap = false
    private var baseMapStyle = ROBBaseMapStyleStore.load()
    private var baseTileOverlay: MKTileOverlay?
    private var overlayCalibration = ROBLidarOverlayCalibrationStore.load()

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
        instructionLabel.text = "Tap the map to choose a destination • Pinch to zoom"
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
        mapView.addGestureRecognizer(tap)

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
        mapStyleButton.menu = UIMenu(
            title: "Map Settings",
            children: [baseMapMenu, scaleMenu, northMenu]
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
        if let baseTileOverlay {
            mapView.removeOverlay(baseTileOverlay)
        }
        baseMapStyle = style
        baseTileOverlay = nil
        mapView.mapType = style == .satellite ? .satellite : .standard
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
        rebuildMapSettingsMenu()
        lidarView.setNeedsDisplay()
    }

    @objc(updateRobotLatitude:longitude:)
    public func updateRobot(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        robotCoordinate = coordinate
        robotAnnotation.coordinate = coordinate
        robotAnnotation.title = "ROB"
        if !mapView.annotations.contains(where: { $0 === robotAnnotation }) {
            mapView.addAnnotation(robotAnnotation)
        }
        lidarView.robotCoordinate = coordinate
        lidarView.setNeedsDisplay()
        if !hasCenteredOnRobot {
            hasCenteredOnRobot = true
            recenter(animated: false)
        }
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
        scanStatusLabel.text = String(
            format: "LIDAR / %04d / %@ / %d%% / N%+.0f°",
            lidarReturnCount,
            gridState,
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
              let robotCoordinate,
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
