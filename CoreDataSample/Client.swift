//
//  Client.swift
//  CoreDataSample
//
//  Created by macbook air on 30/12/2018.
//  Copyright © 2018 a.lapatin@icloud.com. All rights reserved.
//

import Foundation
import AVFoundation

class TCPClient: NSObject {
    
    let netServiceType = "_babywatcher._tcp."
    
    var serviceBrowser: NetServiceBrowser!
    var services: [NetService] = []
    var servicesCallback: (([NetService]) -> Void)?
    
    var streamsConnected = false
    var streamsConnectedCallback: (() -> Void)?
    
    let serviceDomain = "local"
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var openedStreams = 0
    
    var isServerReady = true
    var elementaryStreamTransport: NSMutableData?
    
    static let shared = TCPClient()
    
    private override init() {
        super.init()
        
        self.startBrowsingServices()
    }
    
    func startBrowsingServices() {
        self.serviceBrowser = NetServiceBrowser()
        self.serviceBrowser?.includesPeerToPeer = true
        self.serviceBrowser?.delegate = self
        self.serviceBrowser?.searchForServices(ofType: netServiceType, inDomain: self.serviceDomain)
    }
    
    func connectTo(service: NetService) {
        
        var inputStream: InputStream?
        var outputStream: OutputStream?
        
        let success = service.getInputStream(&inputStream, outputStream: &outputStream)
        
        if !success {
            return print("could not connect to service")
        }
        self.inputStream  = inputStream
        self.outputStream = outputStream
        
        self.openStreams()
        
        print("connecting...")
    }
    
    func openStreams() {
        guard self.openedStreams == 0 else {
            return print("streams already opened... \(self.openedStreams)")
        }
        
        self.inputStream?.delegate = self
        self.inputStream?.schedule(in: .current, forMode: .default)
        self.inputStream?.open()
        
        self.outputStream?.delegate = self
        self.outputStream?.schedule(in: .current, forMode: .default)
        self.outputStream?.open()
   
        print("Open streams")
        }
    
    func closeStreams() {
        print("close stream")
        self.inputStream?.remove(from: .current, forMode: .default)
        self.inputStream?.close()
        self.inputStream = nil
        
        self.outputStream?.remove(from: .current, forMode: .default)
        self.outputStream?.close()
        self.outputStream = nil
        
        self.streamsConnected = false
        self.openedStreams = 0
    }
    
    func send() {

        let data = "Hello, World".data(using: .utf8)!
        let _ = data.withUnsafeBytes { self.outputStream?.write($0, maxLength: data.count) }
    }
    
    
    func sendVideoFrames (frame: NSMutableData){
//        print("send video")
//        let bufferData = bufferToUInt(sampleBuffer: frame)
        var bytes = [UInt8](frame as Data)
        print("--------------------------------")
        print(" Bytes count: \(bytes.count)")
        print("--------------------------------")
        self.outputStream?.write(bytes, maxLength: bytes.count)
    }
    
    private func bufferToUInt(sampleBuffer: CMSampleBuffer) -> [UInt8] {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let byterPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
//        let format = CVPixelBufferGetPixelFormatType(imageBuffer)
//        let width = CVPixelBufferGetWidth(imageBuffer)
//        let duration = CMSampleBufferGetDuration(sampleBuffer)
//        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let srcBuff = CVPixelBufferGetBaseAddress(imageBuffer)
        let data = NSData(bytes: srcBuff, length: byterPerRow * height)
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return [UInt8](data as Data)
    }
}
    
extension TCPClient: NetServiceBrowserDelegate {
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("service found:" + service.name)
        self.services.append(service)
        
        if !moreComing {
            if let service = self.services.first {
                self.connectTo(service: service)
            }
        }
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("service removed:" + service.name)
        self.services = self.services.filter() { $0 != service }
        
        if !moreComing {
            if let service = self.services.first {
                self.connectTo(service: service)
            }
        }
    }
}

extension TCPClient: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        
        if eventCode.contains(.hasBytesAvailable) {
            
            guard let inputStream = self.inputStream else {
                return print("no input stream")
            }
            
            let bufferSize     = 8
            var buffer         = Array<UInt8>(repeating: 0, count: bufferSize)
            
            
            while inputStream.hasBytesAvailable {
                var bytesFromStream = inputStream.read(&buffer, maxLength: bufferSize)
            }
            
            if buffer == [0,0,1,1,0,0,1,1] {
                print("Ready from server")
                TCPClient.shared.isServerReady = true
            }
            
        }
        
        
        //        if TCPClient.shared.elementaryStreamTransport != nil {
        //            TCPClient.shared.sendVideoFrames(frame: TCPClient.shared.elementaryStreamTransport!)
        //        } else {print("Error: Elementary stream transport = nil")}
        
    }
}
