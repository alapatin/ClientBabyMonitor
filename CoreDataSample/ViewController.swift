//
//  ViewController.swift
//  CoreDataSample
//
//  Created by macbook air on 28/12/2018.
//  Copyright © 2018 a.lapatin@icloud.com. All rights reserved.
//

import UIKit
import AVFoundation
import VideoToolbox


class ViewController: UIViewController {
    
    var captureSession: AVCaptureSession!
    var compressionSession: VTCompressionSession!
    var discoverySession: AVCaptureDevice.DiscoverySession!
    //    var captureDevice: AVCaptureDevice?
    var cameraInput: AVCaptureDeviceInput?
    
    @IBOutlet weak var previewView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        TCPClient.shared
        
        // Find and get Camera
        
        discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
            [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera],
                                                            mediaType: .video, position: .unspecified)
        
        func bestDevice(in position: AVCaptureDevice.Position) -> AVCaptureDevice {
            let devices = discoverySession.devices
            guard !devices.isEmpty else { fatalError("Missing capture devices.")}
            return devices.first(where: { device in device.position == position })!
        }
        
        let captureDevice = bestDevice(in: .back)
        
        
        // Create Session
        
        captureSession = AVCaptureSession()
        
        
        // Add Camera to Input
        
        do {
            cameraInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch let error as NSError {
            print(error)
        }
        
        
        // Add Input to Session
        
        if captureSession.canAddInput(cameraInput!){
            captureSession.addInput(cameraInput!)
        } else {
            fatalError("Can't add input to the session")
        }
        
        
        // Add Output to Session
        
        let sessionOutput = AVCaptureVideoDataOutput()
        
        sessionOutput.alwaysDiscardsLateVideoFrames = true
        let queue = DispatchQueue.main
        sessionOutput.setSampleBufferDelegate(self, queue: queue)
        guard captureSession.canAddOutput(sessionOutput) else {fatalError()}
        
        captureSession.addOutput(sessionOutput)
        
        
        // Add Compression Session
        
        //        var pointerCompression: UnsafeMutablePointer<VTCompressionSession?>
        //        let statusCompressionSession = VTCompressionSessionCreate(allocator: nil,
        //                                                             width: 200,
        //                                                             height: 320,
        //                                                             codecType: kCMVideoCodecType_H264,
        //                                                             encoderSpecification: nil,
        //                                                             imageBufferAttributes: nil,
        //                                                             compressedDataAllocator: nil,
        //                                                             outputCallback: nil,
        //                                                             refcon: nil,
        //                                                             compressionSessionOut: pointerCompression)
        //        self.compressionSession = pointerCompression.pointee!
        
        
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds
        previewView.layer.addSublayer(videoPreviewLayer)
        captureSession.startRunning()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if CMSampleBufferDataIsReady(sampleBuffer) {
            TCPClient.shared.sendVideoFrames(frame: sampleBuffer)
        }
    }
}

