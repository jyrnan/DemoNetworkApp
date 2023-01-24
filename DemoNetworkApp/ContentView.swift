//
//  ContentView.swift
//  
//
//  Created by jyrnan on 2023/1/12.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: AppViewModel
    @State var currentTab: String = "Device"
    
    var body: some View {
        TabView(selection: $currentTab) {
            DeviceView(vm: vm).tag("Device")
            ActionView(vm: vm).tag("Action")
            LogView(vm:vm).tag("Log")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.shared)
    }
}
