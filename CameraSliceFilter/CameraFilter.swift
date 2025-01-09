//
//  CameraFilter.swift
//  CameraSliceFilter
//
//  Created by Anubhav Rawat on 03/12/24.
//

import SwiftUI

struct CameraFilter: View {
    
    @StateObject var viewModel = ViewController()
    
    var body: some View {
        ZStack{
            ZStack(alignment: .top){
                CameraPreviewRepresentable(captureSession: viewModel.captureSession)
                    .frame(height: viewModel.cameraHeight)
                
                if let currentImage = viewModel.imageGenerated{
                    
                    
                    Image(uiImage: currentImage)
                        .resizable()
                        .scaledToFit()
                        .mask(alignment: .top) {
                            Rectangle().frame(height: viewModel.cameraHeight * viewModel.percentComplete)
                        }
                    
                    if viewModel.isProcessing{
                        Rectangle().fill(.orange)
                            .frame(height: 0.5)
                            .offset(y: viewModel.cameraHeight * viewModel.percentComplete)
                    }
                }
            }
            .frame(height: viewModel.cameraHeight)
            
            //            Buttons
            VStack{
                Spacer()
                HStack{
                    if viewModel.imageGenerated != nil{
                        Button {
                            Task{
                                if let imageGenerated = viewModel.imageGenerated{
                                    await viewModel.saveImage.saveImage(imageGenerated: imageGenerated)
                                }
                            }
                        } label: {
                            Text("Save Image")
                                .padding(.all, 10)
                                .background(Capsule().fill(.orange))
                        }
                        .disabled(viewModel.isProcessing)
                        
                    }
                    
                    Button {
                        viewModel.startProcessing()
                    } label: {
                        Text(viewModel.imageGenerated == nil ? "Start Capturing" : "Retake")
                            .padding(.all, 10)
                            .background(Capsule().fill(.orange))
                        
                    }
                    .disabled(viewModel.isProcessing)
                    
                }
                .padding(.bottom, 30)
            }
            
        }
    }
}
