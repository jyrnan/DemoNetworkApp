//
//  DeviceView.swift
//
//  Created by jyrnan on 2023/1/12.
//

import SwiftUI

struct DeviceView: View {
    @ObservedObject var vm: AppViewModel
    @State var IPinput: String
    
    init(vm: AppViewModel) {
        self.vm = vm
        self.IPinput = vm.getWiFiAddress() ?? ""
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                List(selection: $vm.hasSelectedDevice) {
                    
                    Section(header: Text("Connect to")
                        ) {
                            HStack {
                                TextField("Input ip:port", text: $IPinput)
                                Spacer()
                                Button("Connect") {
                                    vm.startConnectionTo(host: IPinput)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(IPinput.count < 4)
                            }.onTapGesture { vm.hideKeyboard() }
                        }
                    
                    Section(header: Text("Local")) {
                        localServer(listener: vm.listenerUdp)
                        localServer(listener: vm.listener)
                        localServer(listener: vm.listenerSSL)
                        
                    }
                    
                    Section(header: Text("Found Device")) {
                        if vm.results.isEmpty {
                            Text("No server found").foregroundColor(.gray)
                        }
                        ForEach(vm.results.map{$0.endpoint},id: \.hashValue) {endpoint in
                            Text(endpoint.debugDescription)
                                .onTapGesture {
                                    if let result = vm.results.filter({$0.endpoint == endpoint}).first {
                                        vm.startConnectionTo(result: result)
                                    }
                                }
                        }
                        
                    }
                    
                    Section(header: Text("Peer Connection")) {
                        if vm.clients.isEmpty && vm.servers.isEmpty {
                            Text("No Connection").foregroundColor(.gray)
                        }
                        
                        ForEach(vm.servers) { peer in
                            deviceView(device: peer)
                        }
                        ForEach(vm.clients) { peer in
                            deviceView(device: peer)
                        }
                    }
                    
                }
                Text(vm.logs.last?.content ?? "").foregroundColor(.gray).padding()
            }
            
            .navigationTitle(Text("Devices"))
        }
        .tabItem { Label("Device", systemImage: "desktopcomputer") }
    }
    
    @ViewBuilder
    func deviceView(device: PeerConnection?) -> some View {
        let isConnected = device?.id == vm.hasSelectedDevice
        HStack {
            Image(systemName:device?.initatedConnection == false ? "desktopcomputer" : "server.rack")
                .font(.title)
                .foregroundColor(isConnected ? .accentColor : .primary)

            Text("\(device?.connection?.endpoint.debugDescription ?? "")")
                .foregroundColor(isConnected ? .accentColor : .primary)
            
            PeertypeView(type: device?.type ?? .tcp)
        }
    }
    
    @ViewBuilder
    func localServer(listener: PeerListener?) -> some View {
        if let port = listener?.listener?.port?.debugDescription, let type = listener?.type {
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.title)
                Text("\(vm.getWiFiAddress() ?? ""):\(port)")
                    .bold()
                PeertypeView(type: type)
            }
        }
    }
}

struct DeviceView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.shared)
    }
}

struct PeertypeView: View {
    var type: PeerType = .tcp
    var body: some View {
        switch type {
        case .udp:
            Text("U").font(.caption)
                .bold().foregroundColor(.white).padding(3)
                .background(Circle().foregroundColor(.green))
        case .tcp:
            Text("T").font(.caption)
                .bold().foregroundColor(.white).padding(3)
                .background(Circle().foregroundColor(.blue))
        case .tcpSSL:
            Text("S").font(.caption)
                .bold().foregroundColor(.white).padding(3)
                .background(Circle().foregroundColor(.orange))
        }
    }
}
