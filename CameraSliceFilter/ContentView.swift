//
//  ContentView.swift
//  CameraSliceFilter
//
//  Created by Anubhav Rawat on 30/11/24.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View{
        NavigationStack{
            VStack(spacing: 20){
                
                NavigationLink {
                    VideoPicker()
                } label: {
                    ZStack{
                        Text("Pick a Video from gallery")
                            .padding(.all, 20)
                            .background(Capsule().fill(.orange))
                    }
                }
                
                
                NavigationLink {
                    CameraFilter()
                } label: {
                    ZStack{
                        Text("Use Camera")
                            .padding(.all, 20)
                            .background(Capsule().fill(.orange))
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
