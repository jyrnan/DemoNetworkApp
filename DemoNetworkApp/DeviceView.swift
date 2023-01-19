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
                    }
                    
                    Section(header: Text("Server")) {
                        if vm.servers.isEmpty {
                            Text("No server").foregroundColor(.gray)
                        }
                        ForEach(vm.servers) { peer in
                            deviceView(device: peer)
                        }
                    }
                    
                    Section(header: Text("Client")) {
                        if vm.clients.isEmpty {
                            Text("No client").foregroundColor(.gray)
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
            Image(systemName: "desktopcomputer")
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
}

struct DeviceView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.mock)
    }
}
