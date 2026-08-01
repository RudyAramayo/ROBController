//
//  Consciousness_WatchApp.swift
//  Consciousness-Watch Watch App
//

import SwiftUI

@main
struct Consciousness_Watch_Watch_AppApp: App {
    @StateObject private var robotController = WatchRobotController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(robotController)
        }
    }
}
