//
//  ContentView.swift
//  go-sdk-demo-app-ios
//
//  Created by Seald on 02/02/2023.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            Button("START SDK DEMO") {
                SDKDemo()
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

func SDKDemo () {
    print("SDKDemo START")
    print("SDKDemo END")
}
