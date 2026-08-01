//
//  ContentView.swift
//  Consciousness-Watch Watch App
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var robotController: WatchRobotController
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                connectionLabel

                NavigationLink {
                    VoiceInputView()
                } label: {
                    Label("Dictate", systemImage: "mic.fill")
                }
                .tint(.blue)

                NavigationLink {
                    DriveControlView()
                } label: {
                    Label("Drive", systemImage: "move.3d")
                }
                .tint(.orange)
                .disabled(!robotController.phoneReachable)
            }
            .navigationTitle("R.O.B.")
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                robotController.applicationBecameInactive()
            }
        }
    }

    private var connectionLabel: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(robotController.phoneReachable ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            Text(robotController.status)
                .font(.caption2)
                .lineLimit(2)
        }
    }
}

private struct VoiceInputView: View {
    @EnvironmentObject private var robotController: WatchRobotController

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                TextFieldLink(
                    prompt: Text("Speak a short message"),
                    label: {
                        Label("Speak", systemImage: "mic.circle.fill")
                            .font(.headline)
                    },
                    onSubmit: { robotController.sendVoiceText($0) }
                )
                .buttonStyle(.borderedProminent)
                .disabled(!robotController.phoneReachable)

                if !robotController.lastVoiceText.isEmpty {
                    Text(robotController.lastVoiceText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(robotController.status)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("Voice")
    }
}

private struct DriveControlView: View {
    @EnvironmentObject private var robotController: WatchRobotController

    var body: some View {
        VStack(spacing: 3) {
            Text(robotController.isDriving ? "Touch held • driving" : "Hold the joystick")
                .font(.caption2)
                .foregroundStyle(robotController.isDriving ? Color.orange : Color.secondary)

            WatchJoystick()
                .environmentObject(robotController)
        }
        .navigationTitle("Drive 35%")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            robotController.endJoystickTouch()
        }
    }
}

private struct WatchJoystick: View {
    @EnvironmentObject private var robotController: WatchRobotController
    @State private var knobOffset = CGSize.zero

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            let knobDiameter = max(34, diameter * 0.28)
            let travelRadius = max(1, (diameter - knobDiameter) / 2)

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.22))
                Circle()
                    .stroke(Color.secondary.opacity(0.55), lineWidth: 1)
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1, height: diameter * 0.72)
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: diameter * 0.72, height: 1)
                Circle()
                    .fill(robotController.isDriving ? Color.orange : Color.blue)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .shadow(radius: 2)
                    .offset(knobOffset)
            }
            .frame(width: diameter, height: diameter)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let distance = hypot(dx, dy)
                        let limit = distance > travelRadius ? travelRadius / distance : 1
                        let limitedX = dx * limit
                        let limitedY = dy * limit
                        knobOffset = CGSize(width: limitedX, height: limitedY)
                        robotController.updateJoystick(
                            x: limitedX / travelRadius,
                            y: -limitedY / travelRadius
                        )
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.12)) {
                            knobOffset = .zero
                        }
                        robotController.endJoystickTouch()
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WatchRobotController())
    }
}
