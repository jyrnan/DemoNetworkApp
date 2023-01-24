//
//  PeerListener.swift
//  DemoNetworkApp
//
//  Created by jyrnan on 2023/1/17.
//

import Foundation
import Network

// 应为Listener需要管理部分Connection，并向上透传connection的调用，所以继承PeerConnectionDelegate
protocol PeerListenerDelegate: PeerConnectionDelegate {
    func ListenerReady()
    func ListenerFailed()
}

class PeerListener {
    // MARK: - Types
    
    enum ServiceType {
        case bonjour
        case applicationService
    }

    // MARK: - Properties
    
    weak var delegate: PeerListenerDelegate?
    var listener: NWListener?
    var port: UInt16 = 8899
    
    var type: PeerType = .tcp
    
    var connectionsByID: [UUID: PeerConnection] = [:]
    
    // 预设连接的类型参数
    var parameters: NWParameters = .tcp
    
    // 用于bonjour发现
    var name: String?
    var passcode: String?
    
    // MARK: - Inits
    
    // 创建一个指定端口号的监听者用来接收连接，根据指定类型来创建非加密tcp或者udp，默认tcp
    init(on port: UInt16, delegate: PeerListenerDelegate, type: PeerType = .tcp) {
        self.port = port
        self.delegate = delegate
        self.type = type
        
        if case .udp = type {
            parameters = .udp
        }
        
        self.setupNoSSLListener()
    }
    
    // 创建一个指定端口号的支持SSL和bonjour监听者用来接收连接
    init(delegate: PeerListenerDelegate, name: String, passcode: String) {
        self.delegate = delegate
        self.name = name
        self.passcode = passcode
        self.type = .tcpSSL
        self.setupBonjourTcpListener()
    }
    
    // MARK: - Setup listener
    
    // 创建一个指定端口号的监听者用来接收连接，根据指定类型来创建tcp或者udp，默认tcp
    private func setupNoSSLListener() {
        do {
            let listener = try NWListener(using: parameters, on: .init(rawValue: port)!)
            self.listener = listener
            
            self.startListening()
        } catch {
            print("创建服务监听失败")
            abort()
        }
    }
    
    private func setupBonjourTcpListener() {
        do {
            guard let name = self.name, let passcode = self.passcode else {
                print("Cannot create Bonjour listener without name and passcode")
                return
            }
            
            let listener = try NWListener(using: NWParameters(passcode: passcode))
            self.listener = listener
            
            // Set the service to advertise.
            listener.service = NWListener.Service(name: name, type: "_demoNWapp._tcp")
            
            self.startListening()
        } catch {
            print("创建服务监听失败")
            abort()
        }
    }
    
    // MARK: - Start and stop
    
    func startListening() {
        // 设置状态改变回调方法
        self.listener?.stateUpdateHandler = self.listenerStateChanged
        
        // 处理新进入的连接的回调方法
        self.listener?.newConnectionHandler = { newConnection in
            
            // 接受传入的NWConnection，并用它创建PeerConnection保存在PeerListener中
            let peerConnection = PeerConnection(connection: newConnection, delegate: self)
            peerConnection.type = self.type
            
            // 保存connection到收到的connection池中
            self.connectionsByID[peerConnection.id] = peerConnection
        }
        
        self.listener?.start(queue: DispatchQueue.global())
    }
    
    func stopListening() {
        if let listener = listener {
            listener.cancel()
        }
        
        self.connectionsByID.values.forEach { $0.cancel() }
        self.connectionsByID.removeAll()
    }

    func setupApplicationServiceListener() {}
    
    func setupBonjourListener() {}
    
    func listenerStateChanged(newState: NWListener.State) {
        switch newState {
        case .setup:
            break
        case .waiting(let error):
            self.delegate?.displayAdvertizeError(error)
        case .ready:
            print("Listener ready on \(String(describing: self.listener?.port))")
            self.delegate?.ListenerReady()
        case .failed(let error):
//            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
//                print("Listener failed with \(error), restarting")
//                self.listener?.cancel()
//                self.setupNoSSLListener()
//            } else {
            print("Listener failed with \(error), stopping")
            self.delegate?.displayAdvertizeError(error)
            self.delegate?.ListenerFailed()
            self.stopListening()
//            }
        case .cancelled:
            self.delegate?.ListenerFailed()
        default:
            break
        }
    }

    // MARK: - Send
    
    func sendTo(id: UUID, message: Data) {
        self.connectionsByID[id]?.send(message: message)
    }
}

// 因为PeerListern需要管理部分传入的Connection所以需要把自身设置成这些connection的代理
extension PeerListener: PeerConnectionDelegate {
    func connectionReady(connection: PeerConnection) {
        self.delegate?.connectionReady(connection: connection)
    }
    
    func connectionFailed(connection: PeerConnection) {
        self.connectionsByID[connection.id] = nil
        self.delegate?.connectionFailed(connection: connection)
    }
    
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message?) {
        self.delegate?.receivedMessage(content: content, message: message)
    }
    
    func displayAdvertizeError(_ error: NWError) {
        self.delegate?.displayAdvertizeError(error)
    }
    
    func connectionError(connection: PeerConnection, error: NWError) {
        self.delegate?.connectionError(connection: connection, error: error)
    }
}
