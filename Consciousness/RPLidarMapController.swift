//
//  RPLidarMapController.swift
//  ROBController
//
//  Created by Rob Makina on 7/27/25.
//  Copyright © 2025 OrbitusRobotics. All rights reserved.
//

import Foundation
import UIKit

@objc(RPLidarMapController)
public class RPLidarMapController: NSObject {
    
    @objc var rpLidarMapView: UIImageView
        
    @objc public init(rpLidarMapView: UIImageView!) {
        self.rpLidarMapView = rpLidarMapView
    }

    @objc public func updateMap(data: Data, width: Int32, height: Int32) {
        let dataBytes = data.bytes
        let image = self.mask(from: dataBytes, dataWidth: width, dataHeight: height)
        DispatchQueue.main.async {
            self.rpLidarMapView.image = image
        }
    }
    
    func mask(from data: [UInt8], dataWidth: Int32, dataHeight: Int32) -> UIImage? {
        guard data.count >= 8 else {
            print("data too small")
            return nil
        }
        
        let width  = Int(dataWidth)
        let height = Int(dataHeight)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard
            data.count >= width * height,
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue),
            let buffer = context.data?.bindMemory(to: UInt8.self, capacity: width * height)
        else {
            return nil
        }
        
        for index in 0 ..< width * height {
            buffer[index] = data[index]
        }
        
        return context.makeImage().flatMap { UIImage(cgImage: $0) }
    }
}

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
