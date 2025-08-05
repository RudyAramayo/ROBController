//
//  RPLidarPolarView.swift
//  RPLidar
//
//  Created by Rob Makina on 4/9/22.
//  Copyright © 2022 OrbitusRobotics. All rights reserved.
//

import UIKit

class RPLidarPolarView: UIView {
    
    @objc public var laserPoints: [NSString] = []
    @objc public var zoomScale: Float = 100

    override func draw(_ rect: CGRect) {
        guard let currentContext: CGContext = UIGraphicsGetCurrentContext() else { return }
        let laserPointSize: CGFloat = 6.0
        let centerPoint = CGPoint(x: self.frame.size.width/2.0, y: self.frame.size.height/2.0)
        currentContext.setStrokeColor(UIColor.white.cgColor)
        currentContext.setFillColor(UIColor.red.cgColor)
        currentContext.setLineWidth(2)
        
        currentContext.addEllipse(in: CGRect(x:centerPoint.x, y: centerPoint.y, width:laserPointSize,height: laserPointSize))
        currentContext.drawPath(using: .fillStroke)
        
        for laserPoint in laserPoints {
            if !laserPoint.isEqual(to: "") {
                let laserData = laserPoint.components(separatedBy: ":")
                let angle = Float(laserData[1]) ?? 0
                let positionX = centerPoint.x
                let positionY = centerPoint.y
                let theta = angle + Float.pi//in Radians, 0 is center, right is +π and left is -π
                let distance = Float(laserData[0]) ?? 0
                
                let x = CGFloat(sin(theta) * distance * zoomScale) + positionX
                let y = CGFloat(cos(theta) * distance * zoomScale) + positionY
                
                currentContext.addEllipse(in: CGRect(x:x, y: y, width:laserPointSize,height: laserPointSize))
                currentContext.drawPath(using: .fillStroke)
            }
        }
    }
}
