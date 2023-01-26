//
//  PeerConnection.swift
//  DemoNetworkApp
//
//  Created by jyrnan on 2023/1/17.
//

import Foundation
import Network

protocol PeerConnectionDelegate: AnyObject {
    func connectionReady(connection: PeerConnection)
    func connectionFailed(connection: PeerConnection)
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message?)
    func displayAdvertizeError(_ error: NWError)
    func connectionError(connection: PeerConnection, error: NWError)
}

enum PeerType: String, CustomStringConvertible {
    var description: String { rawValue }
    
    case udp
    case tcp
    case tls // 支持bonjour发现和PSK的tls连接
}

class PeerConnection {
    // MARK: - Properties

    weak var delegate: PeerConnectionDelegate?
    
    var connection: NWConnection?
    let endPoint: NWEndpoint?
    let id: UUID = .init()
    
    // 以连接ip和端口号作为该连接的名字，连接准备就绪时会修改成ip和端口号
    var name: String = ""
    
    // 标识连接类型
    var type: PeerType = .tcp
    
    // 预设连接的类型参数
    var parameters: NWParameters = .tcp
    
    // 标记连接是主动发起连接还是被动接入连接
    let initatedConnection: Bool
    
    var heartbeatTimer:Timer?
    
    // MARK: - inits
    
    // 创建主动发起的连接，根据连接类型创建不支持SSL的udp或tcp连接
    init(endpoint: NWEndpoint, delegat: PeerConnectionDelegate, type: PeerType = .tcp) {
        self.delegate = delegat
        self.endPoint = endpoint
        self.type = type
        
        if case .udp = type {
            parameters = .udp
        }
        
        let connection = NWConnection(to: endpoint, using: parameters)
        self.connection = connection
        self.initatedConnection = true

        startConnection()
    }
    
    // 创建主动发起tcpSSL，支持bonjour的连接。设置网络途径(interface)，passcode用来创建tls连接
    init(endpoint: NWEndpoint, interface: NWInterface?, passcode: String, delegat: PeerConnectionDelegate) {
        self.delegate = delegat
        self.endPoint = endpoint
        self.type = .tls
        
        let connection = NWConnection(to: endpoint, using: passcode == "" ? .tcp : NWParameters(passcode: passcode))
        self.connection = connection
        self.initatedConnection = true

        startConnection()
    }
    
    // 创建收到连接请求时候的被动接入连接
    init(connection: NWConnection, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.endPoint = nil

        self.connection = connection
        self.initatedConnection = false
        
        startConnection()
    }
    
    // MARK: - Start and stop
    
    func cancel() {
        if let connection = connection {
            connection.cancel()
            self.connection = nil
        }
    }
    
    // 针对发起和接入两种连接进行启动相关设置
    // 该方法主要设置stateUpdateHandler用来处理NWConnection各种状态
    // 并设置NWConnection启动
    func startConnection() {
        guard let connection = connection else { return }
        
        connection.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            
            switch newState {
            case .ready:
                self.name = connection.endpoint.debugDescription
                print("\(connection) established")
                
                // 如果准备就绪就开始接收消息
                self.setReceive()
                
                // 通知代理已经准备好
                if let delegate = self.delegate {
                    delegate.connectionReady(connection: self)
                }
            
            case .failed(let error):
                print("\(connection) faild with \(error)")
                
                // 因为错误调用取消方法来中断连接
                connection.cancel()
                
                // 依据情况决定是否重新连接,条件：如果是主动发起连接，并且错误是对方
                if let endPoint = self.endPoint,
                   self.initatedConnection,
                   error == NWError.posix(.ECONNABORTED)
                {
                    // 符合条件的话重新创建连接
                    let connection = NWConnection(to: endPoint, using: self.parameters)
                    self.connection = connection
                    self.startConnection()
                } else if let delegate = self.delegate {
                    // 通知代理连接已经断开
                    delegate.connectionFailed(connection: self)
                }
            case .cancelled:
                self.delegate?.connectionFailed(connection: self)
            default:
                break
            }
        }
        
        // TODO: - 可以设置更灵活的queue
        connection.start(queue: DispatchQueue.main)
        
        startHeartbeat()
    }
    
    // MARK: - Send
    
    // 设置发送消息，这里其实包括了三类形式：UDP直接发送， TLS下采用自定义形式，TCP下采用通用的封包方式
    func send(content: Data) {
        guard let connection = connection else { return }
        
        // 如果是UDP连接协议，则采用这部分的接收方法
        if case .udp = type {
            print("Send \(content.count) bytes")
            
            connection.send(content: content, completion: .contentProcessed { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.delegate?.connectionError(connection: self, error: error)
                }
            })
            
            return
        }
        
        // 如果是SSL连接协议，则采用这部分的接收方法
        // 这部分对于数据处理采用了NWProtocolFramer协议
        // 设置发送消息，可以参考 sendMove(_ move: String)
        if case .tls = type {
            // 先创建NWProtocolFramer.Message，主要是内容是message的type
            let message = NWProtocolFramer.Message(peerMessageType: .data)
            //将message放置在metaData中，来创建context
            let context = NWConnection.ContentContext(identifier: "Data", metadata: [message])
            // 通过connection发送时候带上context参数，isComplete设置成true
            connection.send(content: content,contentContext: context, isComplete: true, completion: .idempotent)
            
            return
        }
        
        // 如果是TCP连接协议，数据采用加入长度头的封包方法，这是通用的封包方法
        let sizePrefix = withUnsafeBytes(of: UInt16(content.count).bigEndian) { Data($0) }
        
        print("Send \(content.count) bytes")
        
        connection.batch {
            connection.send(content: sizePrefix, completion: .contentProcessed { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.connectionError(connection: self, error: error)
                }
            })
            connection.send(content: content, completion: .contentProcessed { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.connectionError(connection: self, error: error)
                }
            })
        }
    }
    
    // MARK: - Receive
    
    func setReceive() {
        switch type {
        case .tcp:
            receiveByStream()
        case .udp:
            receiveByMessage()
        case .tls:
            receiveByPeerMessage()
        }
    }
    
    // 设置接收消息，转交给代理，并接受下一个消息 主要用于UDP？
    func receiveByMessage() {
        guard let connection = connection else { return }
        
        connection.receiveMessage { content, context, _, error in
            
            if let data = content, !data.isEmpty {
                self.delegate?.receivedMessage(content: content, message: nil)
            }
            
            if let error = error {
                self.delegate?.connectionError(connection: self, error: error)
            } else {
                // 继续处理下一个消息
                self.receiveByMessage()
            }
        }
    }
    
    // 设置接收指定字节数据，主要用于TCP？
    func receiveByStream() {
        connection?.receive(minimumIncompleteLength: MemoryLayout<UInt16>.size, maximumLength: MemoryLayout<UInt16>.size) { content, context, isComplete, error in
            var sizePrefix: UInt16 = 0
            
            // 解码获取长度值
            if let data = content, !data.isEmpty {
                sizePrefix = data.withUnsafeBytes { ptr in
                    ptr.bindMemory(to: UInt16.self)[0].bigEndian
                }
            }
            
            if isComplete {
                self.cancel()
            }
            
            if let error = error {
                self.delegate?.displayAdvertizeError(error)
            } else {
                // 获得数据包长度，继续调用方法获得该长度的数据
                self.connection?.receive(minimumIncompleteLength: Int(sizePrefix), maximumLength: Int(sizePrefix)) { content, context, isComplete, error in
                    if let data = content, !data.isEmpty {
                        self.delegate?.receivedMessage(content: data, message: nil)
                    }
                    
                    if isComplete {
                        self.cancel()
                    }
                    
                    if let error = error {
                        self.delegate?.connectionError(connection: self, error: error)
                    } else {
                        // 继续处理下一个消息
                        self.receiveByStream()
                    }
                }
            }
        }
    }
    
    // 设置通过PeerMessage来实现收发，用于SSL
    func receiveByPeerMessage(){
        guard let connection = connection else { return }
        
        connection.receiveMessage { (content, context, isComplete, error) in
            if let message = context?.protocolMetadata(definition: PeerProtocol.definition) as? NWProtocolFramer.Message {
                self.delegate?.receivedMessage(content: content, message: message)
            }
            
            if error == nil {
                self.receiveByPeerMessage()
            }
        }
    }
    
    //MARK: - Heartbeat
    
    func startHeartbeat() {
        
        guard initatedConnection, case .tls = type else { return }
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true, block: { _ in
            self.sendHeartbeat()
        })
        
        heartbeatTimer?.fire()
    }
    
    private func sendHeartbeat() {
        guard let connection = connection else { return }
        
        let timestamp = Date()
//        print("server heartbeat, timestamp: \(timestamp)")
        
        let content = "heartbeat, connection: \(self.name), timestamp: \(timestamp)\r\n".data(using: .utf8)
        
        let message = NWProtocolFramer.Message(peerMessageType: .heart)
        let context = NWConnection.ContentContext(identifier: "heartbeat", metadata: [message])
        
        connection.send(content: content, contentContext: context, isComplete: true ,completion: .idempotent)
//        print(#line, context.identifier)
    }
}

extension PeerConnection: Identifiable {}

extension PeerConnection: Hashable {
    static func == (lhs: PeerConnection, rhs: PeerConnection) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
    
