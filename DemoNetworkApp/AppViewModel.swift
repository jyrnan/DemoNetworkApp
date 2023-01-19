//
//  AppViewModel.swift
//
//  Created by jyrnan on 2023/1/12.
//

import SwiftUI
import Network

class YMLNetwork {}

class AppViewModel: ObservableObject, PeerListenerDelegate {
    //MARK: - Types
    
    enum AppType {
        case SERVER
        case CLIENT
    }
    
    
    static let mock = AppViewModel()
//    static let shared = AppViewModel()
            
    private init() {startListen()}
    
    var listener: PeerListener?
    var connection: PeerConnection?
        
    @Published var servers: [PeerConnection] = []
    @Published var clients: [PeerConnection] = []
    @Published var logs: [Log] = [Log(content: "Sample string")]
    @Published var hasSelectedDevice: UUID?
    
    var willConnectToDevice: PeerConnection?
    
    let testData: Data = "Test Data".data(using: .utf8)!
    
    func startListen() {
        guard listener == nil else {return}
        listener = PeerListener(on: 8899, delegate: self)
    }
    
    func startConnectionTo(host: String) {
        let endppint = NWEndpoint.hostPort(host: .init(host), port: .init(rawValue: 8899)!)
        
        guard servers.filter({$0.endPoint == endppint}).isEmpty else {return}
        connection = PeerConnection(endpoint: endppint, interface: nil, passcode: "", delegat: self)
//        servers.append(connection)
    }
    
//    func send(message: Data) {
//        connection?.sendMessage(message: message)
//    }
    
    func sendTo(connectionID: UUID, message: Data) {
        listener?.connectionsByID[connectionID]?.sendMessage(message: message)
        if let connection = self.servers.filter({$0.id == connectionID}).first {
            connection.sendMessage(message: message)
        }
    }
    
    // MARK: - Private method
    
    private func updateLog(with string: String) {
        let time = Date.now
        let timeStr = time.formatted(date: .omitted, time: .shortened)
        
        DispatchQueue.main.async {
            self.logs.append(Log(content: timeStr + ": " + string))
        }
    }
    
    private func setSelectedDevice(device: PeerConnection?) {
        DispatchQueue.main.async { [self] in
            self.hasSelectedDevice = device?.id
            willConnectToDevice = nil
        }
    }
    
    func addClientPeer(connection: PeerConnection) {
        DispatchQueue.main.async {
            self.clients.append(connection)
        }
    }
    
    func removedConnection(connection: PeerConnection) {
        DispatchQueue.main.async {
            try? self.clients.removeAll(where: {$0.id == connection.id})
            try? self.servers.removeAll(where: {$0.id == connection.id})
        }
    }
    
    func addServerPeer(connection: PeerConnection) {
        DispatchQueue.main.async {
            self.servers.append(connection)
        }
    }
    
    // MARK: - ConnectionProtocol

    func connectionReady(connection: PeerConnection) {
        updateLog(with: "Connection ready")
        if connection.initatedConnection {
            addServerPeer(connection: connection)
        } else {
            addClientPeer(connection: connection)
        }
    }
    
    func connectionFailed(connection: PeerConnection) {
        updateLog(with: "Connection failed")
        removedConnection(connection: connection)
    }
    
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message?) {
        if let content = content, let contentStr = String(data: content, encoding: .utf8) {
            updateLog(with: contentStr)
        }
    }
    
    func displayAdvertizeError(_ error: NWError) {
        updateLog(with: error.debugDescription)
    }
    
    func connectionError(connection: PeerConnection, error: NWError) {
    }
    
    // MARK: - ListenerProtocol

    
    func ListenerReady() {
        updateLog(with: "Listening started")
    }
    
    func ListenerFailed() {
        updateLog(with: "Listening failed")
    }
}

struct Log: Identifiable {
    var id: UUID = .init()
    var content: String
}

extension AppViewModel {
    /// 获取本机Wi-Fi的IP地址
    /// - Returns: IP address of WiFi interface (en0) as a String, or `nil`
    func getWiFiAddress() -> String? {
        var address: String?
            
        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                let flags = Int32((ptr?.pointee.ifa_flags)!)
                var addr = ptr!.pointee.ifa_addr.pointee
                
                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) // || addr?.sa_family == UInt8(AF_INET6)
                    {
                        if String(cString: ptr!.pointee.ifa_name) == "en0" {
                            // Convert interface address to a human readable string:
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                           nil, socklen_t(0), NI_NUMERICHOST) == 0
                            {
                                address = String(validatingUTF8: hostname)
                            }
                        }
                    }
                }
                ptr = ptr?.pointee.ifa_next
            }

            freeifaddrs(ifaddr)
        }
        return address
    }
}

extension AppViewModel {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
