//
//  LogView.swift
//
//  Created by jyrnan on 2023/1/12.
//

import SwiftUI

struct LogView: View {
    @ObservedObject var vm: AppViewModel
    
    var body: some View {
        NavigationView{
                List(vm.logs) {log in
                    Text(log.content)
                }
            .navigationTitle(Text("Logs"))
            
        }
        .tabItem{
            Label("Log", systemImage: "info.bubble")
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(vm: AppViewModel.mock)
    }
}
