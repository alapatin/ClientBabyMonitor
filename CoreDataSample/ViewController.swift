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
    
    var discoverySession: AVCaptureDevice.DiscoverySession!
    //    var captureDevice: AVCaptureDevice?
    var cameraInput: AVCaptureDeviceInput?
    
    var compressionSession: VTCompressionSession!
    var outputCallbackCompression: VTCompressionOutputCallback?
//    let pointerCompression: UnsafeMutablePointer<VTCompressionSession?>? = nil
    
    var sampleBufferTest: CMSampleBuffer?
    let videoPreviewView = AVSampleBufferDisplayLayer()
    
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
        
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds
        previewView.layer.addSublayer(videoPreviewLayer)
        
        captureSession.startRunning()
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
// Add Compression Session
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Can't create Image Buffer in compression session")
            return
        }
        let imageWidth = CVPixelBufferGetWidth(imageBuffer)
        let imageHeight = CVPixelBufferGetHeight(imageBuffer)
        
        let statusCompressionSession = VTCompressionSessionCreate(allocator: nil,
                                                                  width: Int32(imageWidth),
                                                                  height: Int32(imageHeight),
                                                                  codecType: kCMVideoCodecType_H264,
                                                                  encoderSpecification: nil,
                                                                  imageBufferAttributes: nil,
                                                                  compressedDataAllocator: nil,
                                                                  outputCallback: outputCallbackProcessing,
                                                                  refcon: nil,
                                                                  compressionSessionOut: &self.compressionSession)
        
        if statusCompressionSession == noErr {
            VTSessionSetProperty(self.compressionSession,
                                 key: kVTCompressionPropertyKey_RealTime,
                                 value: kCFBooleanTrue)
        } else { print("Can't create compression session")}
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        
        let statusEncodFrame = VTCompressionSessionEncodeFrame(self.compressionSession,
                                        imageBuffer: imageBuffer,
                                        presentationTimeStamp: timeStamp,
                                        duration: duration,
                                        frameProperties: nil,
                                        sourceFrameRefcon: nil,
                                        infoFlagsOut: nil)
        if statusEncodFrame != noErr {
            print("Can't encode frame in compression session")
        }
        
        let statusCompressionComplite = VTCompressionSessionCompleteFrames(self.compressionSession,
                                                                           untilPresentationTimeStamp: .invalid)
        if statusCompressionComplite != noErr {
            print("Can't encode complete frames")
        }
        
        VTCompressionSessionInvalidate(self.compressionSession)
    }
}

func outputCallbackProcessing (outputCallbackRefCon: UnsafeMutableRawPointer?,
                               sourceFrameRefCon: UnsafeMutableRawPointer?,
                               status: OSStatus,
                               infoFlags: VTEncodeInfoFlags,
                               sampleBuffer: CMSampleBuffer?) -> Void {
    
    if status != noErr {
        print("Error: Callback processing status error")
    }
    
    let elementaryStream = NSMutableData()
    
    var isIFrame = false
    guard let sampleBuffer = sampleBuffer else {
        print("Error: In callback processing sampleBuffer = nil")
        return
    }
    
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                                                                 createIfNecessary: true) {
        print("attachments: \(attachments)")

        let rawDic: UnsafeRawPointer = CFArrayGetValueAtIndex(attachments, 0)
        let dic: CFDictionary = Unmanaged.fromOpaque(rawDic).takeUnretainedValue()

        // if not contains means it's an IDR frame
        let keyFrame = !CFDictionaryContainsKey(dic, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
        if keyFrame {
            print("IDR frame")
            isIFrame = true
        }
    } else {print("non IDR frame")}
    
    //2. define the start code
    let nStartCodeLength:size_t = 4
    let nStartCode:[UInt8] = [0x00, 0x00, 0x00, 0x01]
    
    //3. write the SPS and PPS before I-frame
    if ( isIFrame == true ){
        let description: CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
        //how many params
        var numberOfParametersSets: size_t = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 0,
                                                           parameterSetPointerOut: nil,
                                                           parameterSetSizeOut: nil,
                                                           parameterSetCountOut: &numberOfParametersSets,
                                                           nalUnitHeaderLengthOut: nil)
        
        
        
        //write each param-set to elementary stream
        print("Write param to elementaryStream ", numberOfParametersSets)
        
        for i in 0..<numberOfParametersSets {
            var parameterSetPointer: UnsafePointer<UInt8>?
            var parameterSetLength: size_t = 0
            
            // ???
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                               parameterSetIndex: i,
                                                               parameterSetPointerOut: &parameterSetPointer,
                                                               parameterSetSizeOut: &parameterSetLength,
                                                               parameterSetCountOut: nil,
                                                               nalUnitHeaderLengthOut: nil)
            
            elementaryStream.append(nStartCode, length: nStartCodeLength)
            elementaryStream.append(parameterSetPointer!, length: parameterSetLength)
        }
        
    }
    
    //4. Get a pointer to the raw AVCC NAL unit data in the sample buffer
    var blockBufferLength:size_t = 0
    var bufferDataPointer: UnsafeMutablePointer<Int8>?
    
    CMBlockBufferGetDataPointer(CMSampleBufferGetDataBuffer(sampleBuffer)!,
                                atOffset: 0,
                                lengthAtOffsetOut: nil,
                                totalLengthOut: &blockBufferLength,
                                dataPointerOut: &bufferDataPointer)
    
    print ("Block length = ", blockBufferLength)
    
    //5. Loop through all the NAL units in the block buffer
    var bufferOffset:size_t = 0
    let AVCCHeaderLength:Int = 4
    
    while (bufferOffset < (blockBufferLength - AVCCHeaderLength) ) {
        // Read the NAL unit length
        var NALUnitLength:UInt32 =  0
        
        guard let bufferDataPointer = bufferDataPointer else {
            print("Error: Read NAL unit bufferDataPoint = nil")
            return
        }

        memcpy(&NALUnitLength, bufferDataPointer + bufferOffset, AVCCHeaderLength)
        
        
        //Big-Endian to Little-Endian
        NALUnitLength = CFSwapInt32(NALUnitLength)
        if ( NALUnitLength > 0 ){
            print ( "NALUnitLen = ", NALUnitLength)
            // Write start code to the elementary stream
            elementaryStream.append(nStartCode, length: nStartCodeLength)
            // Write the NAL unit without the AVCC length header to the elementary stream
            elementaryStream.append(bufferDataPointer + bufferOffset + AVCCHeaderLength, length: Int(NALUnitLength))
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + size_t(NALUnitLength);
            print("Moving to next NALU...")
        }
    }
    print("Read completed...")
    TCPClient.shared.sendVideoFrames(frame: elementaryStream)
}

