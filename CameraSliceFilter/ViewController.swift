//
//  ViewController.swift
//  CameraSliceFilter
//
//  Created by Anubhav Rawat on 30/11/24.
//

import SwiftUI
import AVFoundation
import Photos

class ViewController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject{
    var captureSession = AVCaptureSession()
    let queue = DispatchQueue(label: "camera.frame.processing")
    
    @Published var imageGenerated: UIImage? = nil
    @Published var isProcessing: Bool = false
    @Published var percentComplete: Double = 0
    @Published var currentSliceNumber: Int = 0
    
    var buffer: CVPixelBuffer? = nil
    var secondsBetweenEachCapture: Double = 0.05
    var sliceHeight: Int = 10
    var currentTime: CMTime = .zero
    var cameraHeight: CGFloat = 500
    
    var saveImage = SaveImage()
    //    var cameraWidth: CGFloat = 450
    
    override init(){
        super.init()
        setupCamera()
    }
    
//    select 60 fps for the camera device. With 1080p mimimum resolution
    private func selectFormat(device: AVCaptureDevice, requiredFrameRate: Double){
        
        try? device.lockForConfiguration()
        let goodFormats: [AVCaptureDevice.Format] = device.formats.filter { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let ranges = format.videoSupportedFrameRateRanges
            if ranges.contains(where: {$0.maxFrameRate >= 60}) && dimensions.width >= 1920 && dimensions.height >= 1080{
                return true
            }else{
                return false
            }
        }
        if let firstFormat = goodFormats.first{
            device.activeFormat = firstFormat
        }
        device.unlockForConfiguration()
    }
    
//    setup capture session
    private func setupCamera(){
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Failed to set up video input.")
            return
        }
        
        captureSession.addInput(videoInput)
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        captureSession.addOutput(videoOutput)
        
        selectFormat(device: videoDevice, requiredFrameRate: 60)
        
        if let connection = videoOutput.connection(with: .video) {
//            connection.videoOrientation = .portrait
            connection.videoRotationAngle = 90
        }
        
        captureSession.commitConfiguration()
        Task{
            captureSession.startRunning()
        }
    }
    
    func startProcessing(){
        self.isProcessing = true
        self.buffer = nil
        self.currentSliceNumber = 0
        self.percentComplete = 0
    }
    
    func stopProcessing() {
        DispatchQueue.main.async{
            self.isProcessing = false
        }
    }
    
//    capture frames from camera.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !isProcessing{
            return
        }
        guard let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else{
            stopProcessing()
            return
        }
        
        let width = CVPixelBufferGetWidth(sourceBuffer)
        let height = CVPixelBufferGetHeight(sourceBuffer)
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if buffer == nil{
            let pixelFormat = CVPixelBufferGetPixelFormatType(sourceBuffer)
            let attributes: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                pixelFormat,
                attributes as CFDictionary,
                &buffer
            )
            if status != kCVReturnSuccess{
                self.stopProcessing()
                print("cannot create new pixel buffer")
                return
            }
        }else{
            let timeDifference = timeStamp - currentTime
            let secondsDifference = timeDifference.seconds
            if secondsDifference < secondsBetweenEachCapture{return}
        }
        
        guard let buffer = buffer else{
            stopProcessing()
            return
        }
        
        CVPixelBufferLockBaseAddress(sourceBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(buffer, [])
        
        //        copying y values
        if let sourceBaseY = CVPixelBufferGetBaseAddressOfPlane(sourceBuffer, 0), let destBaseY = CVPixelBufferGetBaseAddressOfPlane(buffer, 0){
            
            let sourceBytesPerRowY = CVPixelBufferGetBytesPerRowOfPlane(sourceBuffer, 0)
            let destBytesPerRowY = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            
            let sourceBytesStartAddress = sourceBaseY + currentSliceNumber * sliceHeight * sourceBytesPerRowY
            
            let destBytesStartAddress = destBaseY + currentSliceNumber * sliceHeight * destBytesPerRowY
            
            for row in 0..<sliceHeight{
                memcpy(destBytesStartAddress + row * destBytesPerRowY, sourceBytesStartAddress + row * sourceBytesPerRowY, min(sourceBytesPerRowY, destBytesPerRowY))
            }
            
        }
        
        //        copying cbcr values
        if let sourceBase = CVPixelBufferGetBaseAddressOfPlane(sourceBuffer, 1), let destBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1){
            let sourceBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(sourceBuffer, 1)
            let destBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            
            let sourceBytesStartAddress = sourceBase + currentSliceNumber * (sliceHeight/2) * sourceBytesPerRow
            let destBytesStartAddress = destBase + currentSliceNumber * (sliceHeight/2) * sourceBytesPerRow
            
            for row in 0..<(sliceHeight/2){
                memcpy(destBytesStartAddress + row * destBytesPerRow, sourceBytesStartAddress + row * sourceBytesPerRow, min(sourceBytesPerRow, destBytesPerRow))
            }
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        CVPixelBufferUnlockBaseAddress(sourceBuffer, .readOnly)
        self.buffer = buffer
        currentSliceNumber += 1
        currentTime = timeStamp
        
        //        create an image with current buffer
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else{
            print("cannot create cgimage")
            return
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        let complete = Double(currentSliceNumber) * Double(sliceHeight)
        let percentComplete = complete / Double(height)
        DispatchQueue.main.async{
            self.imageGenerated = uiImage
            self.percentComplete = percentComplete
        }
        
        //        if the next slice cannot fit in the buffer, stop the capture
        let filledUpTo = currentSliceNumber * sliceHeight
        let limit = height
        
        if filledUpTo + sliceHeight > limit{
            self.stopProcessing()
        }
        
        
    }
    
    
    
}

class SaveImage: NSObject{
    private func checkPhotoLibraryAuthorisation() async -> Bool{
        let readWriteAccess = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if readWriteAccess == .authorized{
            return true
        }
        
        let access = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        
        if access == .authorized || access == .limited{
            return true
        }else{
            return false
        }
    }
    
    //    save image to photo library
    func saveImage(imageGenerated: UIImage) async {
        guard await checkPhotoLibraryAuthorisation() == true else{return}
        
        UIImageWriteToSavedPhotosAlbum(imageGenerated, self, #selector(saveCompleted), nil)
        
    }
    
    @objc private func saveCompleted(image: UIImage, error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Save failed: \(error.localizedDescription)")
        } else {
            ("Save successful!")
        }
    }
}
