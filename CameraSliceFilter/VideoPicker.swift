//
//  VideoPicker.swift
//  CameraSliceFilter
//
//  Created by Anubhav Rawat on 03/12/24.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct Movie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "movie.mp4")
            
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

class VideoPickerViewModel: ObservableObject{
    
    @Published var image: UIImage? = nil
    var saveImage = SaveImage()
    
    private func getPixelBuffers(url: URL) async -> [CVPixelBuffer] {
        
        let asset = AVURLAsset(url: url)
        guard let reader = try? AVAssetReader(asset: asset), let videoTrack = try? await asset.loadTracks(withMediaType: .video).first, let duration = try? await asset.load(.duration) else{return []}
        
        reader.timeRange = CMTimeRange(start: CMTime(seconds: 0, preferredTimescale: 600), duration: duration)
        
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        
        if reader.canAdd(videoOutput){
            reader.add(videoOutput)
        }else{
            print("cannot add output")
            return []
        }
        
        var bufferCount = 0
        var buffers: [CVPixelBuffer] = []
        if reader.startReading(){
            while let sampleBuffer = videoOutput.copyNextSampleBuffer(){
                
                bufferCount += 1
                if bufferCount % 10 == 0, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer){
                    buffers.append(pixelBuffer)
                }
                
            }
        }
        
        return buffers
    }
    
    func createImage(url: URL) async {
        
        let buffers = await getPixelBuffers(url: url)
        
        let count = buffers.count
        
        let width = CVPixelBufferGetWidth(buffers[0])
        let height = CVPixelBufferGetHeight(buffers[0])
        
        print("width of each buffer: \(width)")
        print("height of each buffer: \(height)")
        
        let heightOfEachSlice = height / count
        
        //        create new pixel buffe
        var newPixelBuffer: CVPixelBuffer?
        let pixelFormat = CVPixelBufferGetPixelFormatType(buffers[0])
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            nil,
            &newPixelBuffer
        )
        
        //        check if creating pixel buffer was success
        guard status == kCVReturnSuccess, let outputBuffer = newPixelBuffer else{
            print("not able to create new pixel buffer \(status.description)")
            return
        }
        
        //        Lock output buffer for writing
        CVPixelBufferLockBaseAddress(outputBuffer, [])
        guard let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer) else{
            CVPixelBufferUnlockBaseAddress(outputBuffer, [])
            print("cannot get output base address")
            return
        }
        
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)
        
        //        enumerate the buffers.
        for (index, buffer) in buffers.enumerated(){
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            
            guard let inputBaseAddress = CVPixelBufferGetBaseAddress(buffer) else{
                CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
                print("cannot get input base address")
                continue
            }
            
            let inputBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            
            let inputStartAddress = inputBaseAddress + index * heightOfEachSlice * inputBytesPerRow
            
            let outputStartAddress = outputBaseAddress + index * heightOfEachSlice * outputBytesPerRow
            
            for row in 0..<heightOfEachSlice{
                memcpy(
                    outputStartAddress + row * outputBytesPerRow,
                    inputStartAddress + row * inputBytesPerRow,
                    outputBytesPerRow
                )
            }
            
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            
        }
        
        CVPixelBufferUnlockBaseAddress(outputBuffer, [])
        
        
        //        create image using pixel buffer
        let ciImage = CIImage(cvPixelBuffer: outputBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else{
            print("cannot create cgimage")
            return
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        self.image = uiImage
    }
}

struct VideoPicker: View {
    
    @StateObject var viewModel = VideoPickerViewModel()
    @State var photosPickerItem: PhotosPickerItem?
    
    @State var pickedURL: URL?
    
    var body: some View {
        VStack{
            if let image = viewModel.image{
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            HStack(spacing: 20){
                PhotosPicker(selection: $photosPickerItem, matching: .videos) {
                    Text("Pick Video")
                        .padding(.all, 10)
                        .background(Capsule().fill(.orange))
                }.onChange(of: photosPickerItem) { oldValue, newValue in
                    viewModel.image = nil
                    print("item picked")
                    Task{
                        if let item = newValue{
                            do{
                                if let movie = try await item.loadTransferable(type: Movie.self){
                                    DispatchQueue.main.async{
                                        print("this is the url: \(movie.url)")
                                        self.pickedURL = movie.url
                                    }
                                }
                            }catch{
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
                
                if viewModel.image != nil{
                    Button {
                        Task{
                            if let image = viewModel.image{
                                await viewModel.saveImage.saveImage(imageGenerated: image)
                            }
                        }
                    } label: {
                        Text("Save Image")
                            .padding(.all, 10)
                            .background(Capsule().fill(.orange))
                    }

                }
                
                if let url = pickedURL{
                    Button {
                        Task{
                            await viewModel.createImage(url: url)
                            DispatchQueue.main.async{
                                self.pickedURL = nil
                            }
                        }
                    } label: {
                        Text("Create Image")
                            .padding(.all, 10)
                            .background(Capsule().fill(.orange))
                    }
                }
            }
            
        }
    }
}
