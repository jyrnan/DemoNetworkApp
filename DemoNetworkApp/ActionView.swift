//
//  ActionView.swift
//
//  Created by jyrnan on 2023/1/12.
//

import SwiftUI

struct ActionView: View {
    @ObservedObject var vm: AppViewModel
    var isPeerConnected: Bool {vm.hasSelectedDevice != nil}
    
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
                    }
//                    Text("IP: \(vm.hasSelectedDevice)")
//                        .padding()
                }
                .padding()
                
                Spacer()
                
                VStack {
                    Button("测试发送TCP数据", action: {
                        guard vm.hasSelectedDevice != nil else {return}
                        vm.sendTo(connectionID: vm.hasSelectedDevice!, message: "TCP Data".data(using: .utf8)!)
                    })
                        .padding()
                        .disabled(!isPeerConnected)
                    Button("测试发送UDP命令", action: {
                        guard vm.hasSelectedDevice != nil else {return}
                        vm.sendTo(connectionID: vm.hasSelectedDevice!, message: "UDP Data".data(using: .utf8)!)
                    })
                        .padding()
                        .disabled(!isPeerConnected)
                    Button("断开当前设备连接", action: {
                        
                    })
                        .padding()
                        .buttonStyle(.borderedProminent)
                        .disabled(!isPeerConnected)
                }
            }
            .padding()
            .navigationTitle("Actions")
        }
        .tabItem{Label("Action", systemImage: "playpause.circle")}
    }
}

struct ActionView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.mock)
        
    }
}