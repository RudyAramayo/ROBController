//
//  ContentView.swift
//  Consciousness-Watch Watch App
//
//  Created by Rob Makina on 9/24/23.
//  Copyright © 2023 OrbitusRobotics. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Push To Talk")
        Spacer()
        
        Button {
            print("round action")
        } label: {
            Image(systemName: "globe")
                .frame(width: 100, height: 100)
                .background(.red)
                .clipShape(.circle)
        }
        
        Text("R.O.B. 3")

    }
}

#Preview {
    ContentView()
}

//
//struct RepresentedRPLidarPolarView: UIViewRepresentable {
//    typealias UIViewType = RPLidarPolarView
//    
//    func makeUIView(context: Context) -> RPLidarPolarView{
//        //return view instance
//        let view = RPLidarPolarView()
//        return view
//    }
//    
//    func updateUIView(_ uiView: RPLidarPolarView, context: Context) {
//        
//    }
//}
