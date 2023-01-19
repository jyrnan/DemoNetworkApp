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

class PeerConnection {
    // MARK: - Properties

    weak var delegate: PeerConnectionDelegate?
    
    var connection: NWConnection?
    let endPoint: NWEndpoint?
    let id: UUID = UUID()
    var name: String = ""
    
    // 预设连接的类型参数
    // TODO: - 创建自定义连接类型参数来实现不同的NWConnection类型
    let parameters: NWParameters = .tcp
    
    // 标记连接是主动发起连接还是被动接入连接
    let initatedConnection: Bool
    
    
    
    // MARK: - Inits
    
    // 创建主动发起的连接。设置网络途径(interface)，passcode用来创建tls连接，这两个参数可以考虑暂时无视
    init(endpoint: NWEndpoint, interface: NWInterface?, passcode: String, delegat: PeerConnectionDelegate) {
        self.delegate = delegat
        self.endPoint = endpoint

        
        let connection = NWConnection(to: endpoint, using: NWParameters(passcode: passcode))
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
    }
    
    // MARK: - Send
    
    // 设置发送消息，可以参考 sendMove(_ move: String)
    func send(message: Data) {
        guard let connection = connection else { return }
        
        // 数据封包方法
        let sizePrefix = withUnsafeBytes(of: UInt16(message.count).bigEndian) { Data($0) }
        
        print("Send \(message.count) bytes")
        
        connection.batch {
            connection.send(content: sizePrefix, completion: .contentProcessed{[weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.connectionError(connection: self, error: error)
                }
            })
            connection.send(content: message, completion: .contentProcessed{[weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.delegate?.connectionError(connection: self, error: error)
                }
            })
        }
    }
    
    // MARK: - Receive
    
    func setReceive() {
            receiveByStream()
    }
    
    // 设置接收消息，转交给代理，并接受下一个消息 主要用于UDP？
    func receiveByMessage() {
        guard let connection = connection else { return }
        
        connection.receiveMessage { content, _, _, error in
            
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
        connection?.receive(minimumIncompleteLength: MemoryLayout<UInt16>.size, maximumLength: MemoryLayout<UInt16>.size) { content, _, isComplete, error in
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
                self.connection?.receive(minimumIncompleteLength: Int(sizePrefix), maximumLength: Int(sizePrefix)) { content, _, isComplete, error in
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
    
