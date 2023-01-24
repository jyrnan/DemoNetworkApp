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
                        localServer
                        localServerSSL
                    }
                    
                    Section(header: Text("Found Device")) {
                        if vm.results.isEmpty {
                            Text("No server found").foregroundColor(.gray)
                        }
                        ForEach(vm.results.map{$0.endpoint},id: \.hashValue) {result in
                            Text(result.debugDescription)
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
        }
    }
    
    @ViewBuilder
    var localServer: some View {
        if let port = vm.listener?.listener?.port?.debugDescription {
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.title)
                Text("\(vm.getWiFiAddress() ?? ""):\(port)")
                    .bold()
            }
        }
    }
    
    @ViewBuilder
    var localServerSSL: some View {
        if let port = vm.listenerSSL?.listener?.port?.debugDescription {
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.title)
                Text("\(vm.getWiFiAddress() ?? ""):\(port)")
                    .bold()
            }
        }
    }
}

struct DeviceView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.mock)
    }
}
