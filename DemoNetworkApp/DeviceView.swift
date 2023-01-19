//
//  DeviceView.swift
//
//  Created by jyrnan on 2023/1/12.
//

import SwiftUI

struct DeviceView: View {
    @ObservedObject var vm: AppViewModel
    @State var IPinput: String = "192.168.1."
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List{
                    Section(header: Text("Connect to")
                        .onTapGesture { vm.hideKeyboard() }) {
                        HStack {
                            TextField("Input server address", text: $IPinput)
                            Spacer()
                            Button("Connect") {
                                vm.startConnectionTo(host: IPinput)
                            }
                                .disabled(IPinput.count < 4)
                        }
                    }
                    
                    Section(header: Text("Local")) {
                        localServer
                        
                    }
                    
                    
                }
                
                
                List(selection: $vm.hasSelectedDevice) {
                    
                    Section(header: Text("Server")) {
                        if vm.servers.isEmpty {
                            Text("No remote server")
                        }
                        ForEach(vm.servers) { peer in
                            deviceView(device: peer)
                        }
                    }
                    

                    Section(header: Text("Client")) {
                        if vm.clients.isEmpty {
                            Text("No client")
                        }
                        ForEach(vm.clients) { peer in
                            deviceView(device: peer)
                        }
                    }
                }
                .refreshable {}
               
                if vm.hasSelectedDevice != nil {
                    Text("connected to: \(vm.hasSelectedDevice.debugDescription)")
                }
            }
            
            .navigationTitle(Text("Devices"))
        }
        .tabItem { Label("Device", systemImage: "desktopcomputer") }
        
    }
    
    @ViewBuilder
    func deviceView(device: PeerConnection?) -> some View {
        let isConnected = device?.id == vm.hasSelectedDevice
        HStack {
            Image(systemName: "desktopcomputer")
                .font(.title)
                .foregroundColor(isConnected ? .accentColor : .primary)

            Text("IP: \(device?.connection?.endpoint.debugDescription ?? "NO")")
        }
    }
    
    @ViewBuilder
    var localServer: some View {
        if let port = vm.listener?.listener?.port?.debugDescription {
            HStack {
                Image(systemName: "desktopcomputer")
                    .font(.title)
                    .foregroundColor(.green)
                Text("Local: \(vm.getWiFiAddress() ?? ""):\(port)")
                    .bold()
                    .foregroundColor(.green)
            }
        }
    }
}

struct DeviceView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.mock)
    }
}
