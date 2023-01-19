//
//  ContentView.swift
//  
//
//  Created by jyrnan on 2023/1/12.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: AppViewModel
    @State var currentTab: String?
    
    var body: some View {
        TabView(selection: $currentTab) {
            DeviceView(vm: vm)
            ActionView(vm: vm)
            LogView(vm:vm)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.mock)
    }
}
