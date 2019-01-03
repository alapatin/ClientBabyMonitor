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
        
        
        self.inputStream?.schedule(in: .current, forMode: .default)
        self.inputStream?.open()
        
        
        self.outputStream?.schedule(in: .current, forMode: .default)
        self.outputStream?.open()
        
        //        let data = "Hello".data(using: .utf8)!
        //        var bytesWritten = data.withUnsafeBytes { self.outputStream?.write($0, maxLength: data.count) }
        
        print("Open streams")
        
        
    }
    
    func closeStreams() {
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
        //        guard self.openedStreams == 2 else {
        //            return print("no open streams \(self.openedStreams)")
        //        }
        //
        //        guard self.outputStream!.hasSpaceAvailable else {
        //            return print("no space available")
        //        }
        
        let data = "Hello, World".data(using: .utf8)!
        
        let bytesWritten = data.withUnsafeBytes { self.outputStream?.write($0, maxLength: data.count) }
        
        //        guard bytesWritten == data.count else {
        //            self.closeStreams()
        //            print("something is wrong...")
        //            return
        //        }
        //        print("data written... \(message)")
    }
    
    
    func sendVideoFrames (frame: CMSampleBuffer){
        
        
        let bufferData = bufferToUInt(sampleBuffer: frame)
        
//        print(bufferData.count)
        self.outputStream?.write(bufferData, maxLength: bufferData.count)
        
//        let pointer = frame!.pointee
//        let str = String(cString: pointer!)
//        let data = str.data(using: .utf8)!
//        let bytesWritten = data.withUnsafeBytes { self.outputStream?.write($0, maxLength: data.count) }
    }
    
    private func bufferToUInt(sampleBuffer: CMSampleBuffer) -> [UInt8] {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        print(CMSampleBufferGetDuration(sampleBuffer))
        print(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let byterPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let format = CVPixelBufferGetPixelFormatType(imageBuffer)
        
        let srcBuff = CVPixelBufferGetBaseAddress(imageBuffer)
        
        print(OSType(format))
//        print("w: \(width), h: \(height), bpr: \(byterPerRow)")
        
        let data = NSData(bytes: srcBuff, length: byterPerRow * height)
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
//        return [UInt8].init(repeating: 0, count: data.length / MemoryLayout<UInt8>.size)
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

//extension TCPClient: StreamDelegate {
//
//    func stream(aStream: Stream, handleEvent eventCode: Stream.Event) {
//        if eventCode.contains(.openCompleted) {
//            self.openedStreams += 1
//            print("Opened streams: \(openedStreams)")
//
//        }
//        if eventCode.contains(.hasSpaceAvailable) {
//            if self.openedStreams == 2 && !self.streamsConnected {
//                print("streams connected.")
//                self.streamsConnected = true
//                self.streamsConnectedCallback?()
//            }
//        }
//    }
//}
//
//extension TCPClient: NetServiceDelegate {
//
//    func netServiceDidResolveAddress(_ sender: NetService) {
//        print("Did resolved addres")
//    }
//
//    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
//        print("Didn't resolved")
//    }
//
//}
