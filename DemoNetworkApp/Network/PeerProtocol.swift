//
//  PeerProtocol.swift
//  DemoNetworkApp
//
//  Created by jyrnan on 2023/1/25.
//

import Foundation
import Network

enum PeerMessageType: UInt32 {
    case invalid = 0
    case heart
    case ack
    case data
}

class PeerProtocol: NWProtocolFramerImplementation {
    
    static let definition = NWProtocolFramer.Definition(implementation: PeerProtocol.self)
    static var label: String = "DemoNWApp"
   
    required init(framer: NWProtocolFramer.Instance) { }
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { return .ready }
    func wakeup(framer: NWProtocolFramer.Instance) { }
    func stop(framer: NWProtocolFramer.Instance) -> Bool { return true }
    func cleanup(framer: NWProtocolFramer.Instance) { }
    
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        
        let type = message.peerMessageType
        
        let header = PeerProtocolHeader(type: type.rawValue, length: UInt32(messageLength))
        
        framer.writeOutput(data: header.encodedData)
        
        do{
            try framer.writeOutputNoCopy(length: messageLength)
        } catch let error {
            print("Hit error writing \(error)")
        }
    }
    
    /// 读取到数据后，从数据中解析出相应的格式
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            // 解出header
            var tempHeader: PeerProtocolHeader? = nil
            let headerSize = PeerProtocolHeader.encodedSize
            
            // 这个方法读取指定的长度，并调用回调
            let parsed = framer.parseInput(minimumIncompleteLength: headerSize,
                                           maximumLength: headerSize) { (buffer, isComplet) -> Int in
                // 如果buffer的长度和预计的不符，则返回0，标识读取光标不往后移
                guard let buffer = buffer else { return 0 }
                if buffer.count < headerSize { return 0 }
                
                // 到这里应该表示buffer的读取长度是符合预期的，可以进行parse
                tempHeader = PeerProtocolHeader(buffer)
                // 返回所读取长度，也就是header的预计长度。数据读取光标会后移该长度
                return headerSize
            }
            
            // 如果parse没有成功，或者没有从buffer里面构建header没成功，
            // 则返回header预计长度，进行下一轮的header的提取
            guard parsed, let header = tempHeader else {return headerSize}
            
            // 到这里应该已经构建了header，从而可以获得后续数据的类型和长度信息
            var messageType: PeerMessageType = .invalid
            // 利用header中的type信息来构造消息类型
            if let parsedMessagetype = PeerMessageType(rawValue: header.type) {
                messageType = parsedMessagetype
            }
            // 利用messageType来构建message
            let message = NWProtocolFramer.Message(peerMessageType: messageType)
            // 发送header中的长度的数据，并将messeage传递
            //message会在上一层次的方法中封装到contextde metadata中传递给应用层
            if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
                return 0
            }
        }
    }
}

extension NWProtocolFramer.Message {
    // 一般是通过消息的类型来构建消息
    convenience init(peerMessageType: PeerMessageType) {
        self.init(definition: PeerProtocol.definition)
        self["PeerMessageType"] = peerMessageType
    }
    // 定义个类型变量方便访问
    var peerMessageType: PeerMessageType {
        if let type = self["PeerMessageType"] as? PeerMessageType {
            return type
        } else {
            return .invalid
        }
    }
}

// 定义该协议中包头header的数据结构，一般是类型和长度，都用UInt32来表示
// 到了数据这个层次，可能更多的需要用整数这样的基本数据来约定相应的类型
struct PeerProtocolHeader: Codable {
    let type: UInt32
    let length: UInt32
    
    init(type:UInt32, length:UInt32) {
        self.type = type
        self.length = length
    }
    // header的最实用的构造方式：从buffer中构造
    init(_ buffer: UnsafeMutableRawBufferPointer) {
        var tempType: UInt32 = 0
        var tempLength: UInt32 = 0
        
        // 从字节中转换成数据格式的方法
        withUnsafeMutableBytes(of: &tempType) {typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress?.advanced(by: 0),
                                                            count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempLength) {typePtr in
            typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress?.advanced(by: MemoryLayout<UInt32>.size),
                                                            count: MemoryLayout<UInt32>.size))
        }
        
        self.type = tempType
        self.length = tempLength
    }
    
    var encodedData: Data {
        var tempType = type
        var tempLength = length
        
        var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
        return data
    }
    
    static var encodedSize: Int {
        MemoryLayout<UInt32>.size * 2
    }
}
