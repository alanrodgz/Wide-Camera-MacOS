//
//  CameraManager.swift
//  Wide Camera
//
//  Created by Alan Rodriguez on 3/11/25.
//

import SwiftUI
import AVFoundation

class CameraManager: NSObject, ObservableObject {
    @Published var cameraPreview: AVCaptureVideoPreviewLayer?
    @Published var isSessionRunning = false
    @Published var availableFormats: [String] = []
    @Published var selectedFormatIndex: Int = 0
    
    private let captureSession = AVCaptureSession()
    private var currentDevice: AVCaptureDevice?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    override init() {
        super.init()
        // Initialize but don't start automatically
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCaptureSession()
                    }
                }
            }
        default:
            break
        }
    }
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        
        // Set high preset to potentially access more camera capabilities
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        
        // Try multiple methods to get the camera
        print("Attempting to find camera devices...")
        
        // Method 1: Using AVCaptureDevice.default
        if let defaultCamera = AVCaptureDevice.default(for: .video) {
            currentDevice = defaultCamera
            print("Found camera using default method: \(defaultCamera.localizedName)")
        }
        // Method 2: Using discovery session
        else {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            let devices = discoverySession.devices
            
            print("Discovery session found \(devices.count) devices:")
            for device in devices {
                print("- Camera: \(device.localizedName), model ID: \(device.modelID)")
            }
            
            if let firstCamera = devices.first {
                currentDevice = firstCamera
                print("Selected first available camera: \(firstCamera.localizedName)")
            } else {
                print("No cameras found through discovery session")
            }
        }
        
        // Final check if we have a camera
        if currentDevice == nil {
            print("WARNING: No camera device could be found")
            captureSession.commitConfiguration()
            return
        }
        
        // Try to get available cameras
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        
        let devices = discoverySession.devices
        
        // Log available devices to help with debugging
        for device in devices {
            print("Available camera: \(device.localizedName), model ID: \(device.modelID)")
        }
        
        // For macOS, get the default video camera
        currentDevice = AVCaptureDevice.default(for: .video)
        print("Selected camera: \(currentDevice?.localizedName ?? "None")")
        
        guard let device = currentDevice else {
            captureSession.commitConfiguration()
            return
        }
        
        // Populate available formats with resolution information
        for (index, format) in device.formats.enumerated() {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            availableFormats.append("[\(index)] \(dimensions.width)x\(dimensions.height)")
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // Setup video output for recording capability
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            
            let videoQueue = DispatchQueue(label: "videoQueue")
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            self.videoOutput = videoOutput
            
            // Create preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            self.cameraPreview = previewLayer
            
            captureSession.commitConfiguration()
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
            captureSession.commitConfiguration()
        }
    }
    
    func startSession() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = self?.captureSession.isRunning ?? false
                }
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
            isSessionRunning = false
        }
    }
    
    func attemptUltraWideCapture() {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Log all available formats for debugging
            print("Available formats for \(device.localizedName):")
            for (index, format) in device.formats.enumerated() {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                print("[\(index)] Format: \(dimensions.width)x\(dimensions.height)")
                
                // Log more details about the format
                if let formatDescription = CMFormatDescriptionGetExtension(
                    format.formatDescription,
                    extensionKey: kCMFormatDescriptionExtension_FormatName) as? String {
                    print("   Format Name: \(formatDescription)")
                }
            }
            
            // Find the format with the highest resolution
            if let highestResFormat = device.formats.max(by: {
                let dim1 = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                let dim2 = CMVideoFormatDescriptionGetDimensions($1.formatDescription)
                return dim1.width * dim1.height < dim2.width * dim2.height
            }) {
                let dimensions = CMVideoFormatDescriptionGetDimensions(highestResFormat.formatDescription)
                print("Selecting highest resolution format: \(dimensions.width)x\(dimensions.height)")
                
                // Configure the session with the highest resolution preset available
                if captureSession.canSetSessionPreset(.high) {
                    captureSession.sessionPreset = .high
                }
            }
            
            // Lock exposure and white balance to prevent automatic adjustments
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
            
            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
            }
            
            device.unlockForConfiguration()
            
            // Restart the session to apply changes
            stopSession()
            startSession()
            
        } catch {
            print("Error configuring camera: \(error.localizedDescription)")
        }
    }
    
    func selectFormat(at index: Int) {
        guard let device = currentDevice,
              index < device.formats.count else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Select the format at the specified index
            let selectedFormat = device.formats[index]
            
            // In macOS, we can't directly set the format like in iOS,
            // but we can adjust the session preset based on the format dimensions
            let dimensions = CMVideoFormatDescriptionGetDimensions(selectedFormat.formatDescription)
            print("Selected format dimensions: \(dimensions.width)x\(dimensions.height)")
            
            // Find a suitable preset based on dimensions
            captureSession.beginConfiguration()
            
            if dimensions.width >= 1920 && captureSession.canSetSessionPreset(.high) {
                captureSession.sessionPreset = .high
            } else if dimensions.width >= 1280 && captureSession.canSetSessionPreset(.medium) {
                captureSession.sessionPreset = .medium
            } else if captureSession.canSetSessionPreset(.low) {
                captureSession.sessionPreset = .low
            }
            
            captureSession.commitConfiguration()
            selectedFormatIndex = index
            
            device.unlockForConfiguration()
            
            // Restart the session to apply changes
            stopSession()
            startSession()
            
        } catch {
            print("Error selecting format: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        // Implementation for recording would go here
        print("Recording started")
    }
    
    func stopRecording() {
        // Implementation for stopping recording would go here
        print("Recording stopped")
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Here we could process the video frames
        // This would be used for recording or custom processing
    }
}
