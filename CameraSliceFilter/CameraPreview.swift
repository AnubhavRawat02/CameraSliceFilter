//
//  CameraPreview.swift
//  CameraSliceFilter
//
//  Created by Anubhav Rawat on 30/11/24.
//

import SwiftUI
import AVFoundation

class CameraPreview: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable{
    
    var captureSession: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreview{
        let view = CameraPreview()
        view.videoPreviewLayer.session = captureSession
        return view
    }
    
    func updateUIView(_ uiView: CameraPreview, context: Context){
        
    }
}
