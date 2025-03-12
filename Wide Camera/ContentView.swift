//
//  ContentView.swift
//  Wide Camera
//
//  Created by Alan Rodriguez on 3/11/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isShowingFormatPicker = false
    
    var body: some View {
        VStack {
            if let cameraPreview = cameraManager.cameraPreview {
                CameraPreviewView(previewLayer: cameraPreview)
                    .frame(minWidth: 640, minHeight: 480)
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.black)
                    .frame(minWidth: 640, minHeight: 480)
                    .cornerRadius(12)
                    .overlay(
                        Text("Camera not available")
                            .foregroundColor(.white)
                    )
            }
            
            VStack(spacing: 16) {
                HStack {
                    Button("Start Camera") {
                        cameraManager.startSession()
                    }
                    .disabled(cameraManager.isSessionRunning)
                    .frame(width: 120)
                    
                    Button("Stop Camera") {
                        cameraManager.stopSession()
                    }
                    .disabled(!cameraManager.isSessionRunning)
                    .frame(width: 120)
                }
                
                HStack {
                    Button("Try Ultra-Wide Mode") {
                        cameraManager.attemptUltraWideCapture()
                    }
                    .disabled(!cameraManager.isSessionRunning)
                    .frame(width: 150)
                    
                    Button("Select Format...") {
                        isShowingFormatPicker = true
                    }
                    .disabled(!cameraManager.isSessionRunning)
                    .frame(width: 120)
                    .popover(isPresented: $isShowingFormatPicker) {
                        formatPickerView
                    }
                    Button("Diagnose Camera Access") {
                        diagnoseCameraAccess()
                    }
                    .padding()
                }
                
                HStack {
                    Button("Start Recording") {
                        cameraManager.startRecording()
                    }
                    .disabled(!cameraManager.isSessionRunning)
                    .frame(width: 120)
                    
                    Button("Stop Recording") {
                        cameraManager.stopRecording()
                    }
                    .disabled(!cameraManager.isSessionRunning)
                    .frame(width: 120)
                }
            }
            .padding()
        }
        .padding()
        .onAppear {
            cameraManager.checkPermissions()
        }
    }
    
    // Add this function to ContentView
    func diagnoseCameraAccess() {
        // Check camera authorization
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        print("Camera authorization status: \(authStatus.rawValue)")
        
        // List all media devices
        let allDevices = AVCaptureDevice.devices()
        print("All media devices (\(allDevices.count)):")
        for device in allDevices {
            print("- \(device.localizedName) (type: \(device.deviceType.rawValue))")
        }
        
        // Try to access the camera directly
        if let camera = AVCaptureDevice.default(for: .video) {
            print("Default camera found: \(camera.localizedName)")
            
            // Try to access format info
            print("Camera formats: \(camera.formats.count)")
            for (i, format) in camera.formats.enumerated() {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                print("Format \(i): \(dimensions.width)x\(dimensions.height)")
            }
        } else {
            print("Could not access default video camera")
        }
    }
    
    var formatPickerView: some View {
        VStack {
            Text("Available Camera Formats")
                .font(.headline)
                .padding()
            
            List(cameraManager.availableFormats.indices, id: \.self) { index in
                HStack {
                    Text(cameraManager.availableFormats[index])
                    
                    if index == cameraManager.selectedFormatIndex {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    cameraManager.selectFormat(at: index)
                    isShowingFormatPicker = false
                }
            }
            .frame(width: 300, height: 300)
            
            Button("Cancel") {
                isShowingFormatPicker = false
            }
            .padding()
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        previewLayer.videoGravity = .resizeAspectFill
        view.layer = previewLayer
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        previewLayer.frame = nsView.bounds
    }
}
