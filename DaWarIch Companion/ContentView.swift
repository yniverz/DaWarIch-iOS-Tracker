//
//  ContentView.swift
//  DaWarIch Companion
//
//  Created by yniverz on 17.01.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    var locationHelper: LocationHelper {
        appDelegate.locationHelper
    }
    
    @State var dawarichServerHost = ""
    @State var dawarichServerKey = ""
    @State var trackingActivated = false
    @State var alwaysHighDensity = false
    @State var debugNotifications = false
    @State var selectedMaxBufferSize = 300
    
    var maxBufferSizes: [Int] = [5, 60, 60*2, 60*5, 60*10]
    
    var body: some View {
        Text("DaWarIch - Tracker")
            .font(.title)
            .fontWeight(.bold)
            .padding(.vertical)
        
        VStack {
            List {
                Section("Server Options") {
                    TextField("Host (Include http/s)", text: $dawarichServerHost)
                        .onChange(of: dawarichServerHost) {
                            locationHelper.dawarichServerHost = dawarichServerHost
                        }
                    TextField("API Key", text: $dawarichServerKey)
                        .onChange(of: dawarichServerKey) {
                            locationHelper.dawarichServerKey = dawarichServerKey
                        }
                    
                }
                Section("Location Options") {
                    Toggle("Tracking Activated", isOn: $trackingActivated)
                        .onChange(of: trackingActivated) {
                            if locationHelper.trackingActivated != trackingActivated {
                                locationHelper.trackingActivated = trackingActivated
                            }
                        }
                    
                    Toggle("Always High Density", isOn: $alwaysHighDensity)
                        .onChange(of: alwaysHighDensity) {
                            if locationHelper.alwaysHighDensity != alwaysHighDensity {
                                locationHelper.alwaysHighDensity = alwaysHighDensity
                            }
                        }
                    
                    Toggle("Debug Notifications", isOn: $debugNotifications)
                        .onChange(of: debugNotifications) {
                            if locationHelper.debugNotifications != debugNotifications {
                                locationHelper.debugNotifications = debugNotifications
                            }
                        }
                    
                    HStack {
                        Text("Buffer length")
                            .frame(alignment: .leading)
                        Text("\(locationHelper.traceBuffer.count)")
                    }
                    
                    Button("Clear Buffer") {
                        locationHelper.clearBuffer()
                    }
                }
                Section("Send Options") {
                    Text("Max Databuffer count:")
                    Picker("MaxBuffer", selection: $selectedMaxBufferSize) {
                        ForEach(0..<maxBufferSizes.count, id: \.self) { sizeIndex in
                            Text("\(maxBufferSizes[sizeIndex])")
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedMaxBufferSize) {
                        locationHelper.selectedMaxBufferSize = maxBufferSizes[selectedMaxBufferSize]
                    }
                    
                }
            }
        }
        .onAppear() {
            dawarichServerHost = locationHelper.dawarichServerHost
            dawarichServerKey = locationHelper.dawarichServerKey
            trackingActivated = locationHelper.trackingActivated
            alwaysHighDensity = locationHelper.alwaysHighDensity
            debugNotifications = locationHelper.debugNotifications
            for index in 0..<maxBufferSizes.count {
                if maxBufferSizes[index] == locationHelper.selectedMaxBufferSize {
                    selectedMaxBufferSize = index
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
