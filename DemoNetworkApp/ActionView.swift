//
//  ActionView.swift
//
//  Created by jyrnan on 2023/1/12.
//

import SwiftUI

struct ActionView: View {
    @ObservedObject var vm: AppViewModel
    @State var text: String = ""
    var isPeerConnected: Bool {vm.hasSelectedDevice != nil}
    var currentConnection: PeerConnection? {
        vm.connections.filter{$0.id == vm.hasSelectedDevice}.first
    }
    
    var body: some View {
        NavigationView{
            VStack {
                VStack{
                    Image(systemName: "desktopcomputer")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .imageScale(.large)
                        .foregroundColor(isPeerConnected ? .accentColor : .gray)
                        .frame(width: 160, height: 160)
                    if isPeerConnected {
                        Text("当前连接设备").padding()
                        HStack {
                            Text(" \(currentConnection?.connection?.endpoint.debugDescription ?? "No peer selected")")
                                .padding()
                            PeertypeView(type:currentConnection?.type ?? .tcp)
                        }
                    }
                    Text("当前无连接设备").padding().opacity(isPeerConnected ? 0 : 1)
                    
                }
                .padding()
                
                Button("断开当前设备连接", action: {
                    if let connection = vm.connections.filter({$0.id == vm.hasSelectedDevice}).first {
                        connection.cancel()
                        vm.hasSelectedDevice = nil
                    }
                })
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .disabled(!isPeerConnected)
                
                Spacer()
                
                VStack(alignment: .center) {
                    TextField("Input test text", text: $text).padding()
                        .textFieldStyle(.roundedBorder)
                    Button("发送测试数据", action: {
                        guard vm.hasSelectedDevice != nil else {return}
                        vm.send(message: text.data(using: .utf8)!,connectionID: vm.hasSelectedDevice!)
                    })
                        .padding()
                        .buttonStyle(.borderedProminent)
                        .disabled(!isPeerConnected || text.isEmpty)
                    
                    
                }
            }
            .padding()
            .navigationTitle("Actions")
        }
        .tabItem{Label("Action", systemImage: "command")}
    }
}

struct ActionView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.mock, currentTab: "Action")
//        ActionView(vm: AppViewModel.mock)
    }
}
