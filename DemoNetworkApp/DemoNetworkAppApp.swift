//
//  DemoNetworkAppApp.swift
//  DemoNetworkApp
//
//  Created by jyrnan on 2023/1/17.
//

import SwiftUI

@main
struct DemoNetworkAppApp: App {
    @StateObject var vm: AppViewModel = AppViewModel.shared
    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
        }
    }
}
