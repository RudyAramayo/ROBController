//
//  Consciousness_WatchApp.swift
//  Consciousness-Watch Watch App
//
//  Created by Rob Makina on 9/24/23.
//  Copyright © 2023 OrbitusRobotics. All rights reserved.
//

import SwiftUI

@main
class Consciousness_Watch_Watch_AppApp: App, AutoNetClientDataDelegate {
    var autoNetClient: AutoNetClient
    //var rpLidarPolarView: RPLidarPolarView = RPLidarPolarView()
    
    required init() {
        self.autoNetClient = AutoNetClient(service:"_roboNet._tcp")
        self.autoNetClient.dataDelegate = self
        self.autoNetClient.start()
    }
    
    func didReceiveData(_ data: NSData) {
        do {
            guard let messageDict = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self], from: data as Data) as? Dictionary<String,String> else {
                print("message dict did not unarchive")
                return
            }
            if let message: String = messageDict["message"],
               let sender: String = messageDict["sender"] {
                print("\(sender): \(message)")
                
                if sender == "rplidar" {
                    var lidarScan = message.components(separatedBy: "\n")
                    //rpLidarPolarView.laserPoints = lidarScan as [NSString]
                    //rpLidarPolarView.setNeedsDisplay()
                }
            }
            
        } catch {
            print("failed to unarchive objects")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
}

