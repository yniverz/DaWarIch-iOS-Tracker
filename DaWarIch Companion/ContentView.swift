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
    
    @State private var dawarichServerHost = ""
    @State private var dawarichServerKey = ""
    @State private var trackingActivated = false
    @State private var alwaysHighDensity = false
    @State private var debugNotifications = false
    @State private var selectedMaxBufferSize = 300
    @State private var bufferLength = 0
    @State private var showingInfoSheet = false
    
    private var maxBufferSizes: [Int] = [5, 60, 60*2, 60*5, 60*10]
    
    var body: some View {
        NavigationStack {
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
                                locationHelper.trackingActivated = trackingActivated
                            }
                        
                        Toggle("Always High Density", isOn: $alwaysHighDensity)
                            .onChange(of: alwaysHighDensity) {
                                locationHelper.alwaysHighDensity = alwaysHighDensity
                            }
                        
                        Toggle("Debug Notifications", isOn: $debugNotifications)
                            .onChange(of: debugNotifications) {
                                locationHelper.debugNotifications = debugNotifications
                            }
                        
                        HStack {
                            Text("Buffer length")
                                .frame(alignment: .leading)
                            Text("\(bufferLength)")
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
            .onAppear {
                dawarichServerHost = locationHelper.dawarichServerHost
                dawarichServerKey = locationHelper.dawarichServerKey
                trackingActivated = locationHelper.trackingActivated
                alwaysHighDensity = locationHelper.alwaysHighDensity
                debugNotifications = locationHelper.debugNotifications
                bufferLength = locationHelper.traceBuffer.count
                // Match the selected index with the stored size
                for index in 0..<maxBufferSizes.count {
                    if maxBufferSizes[index] == locationHelper.selectedMaxBufferSize {
                        selectedMaxBufferSize = index
                        break
                    }
                }
            }
            // Place an info button on the trailing edge of the navigation bar
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingInfoSheet.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            // Show the sheet when the button is tapped
            .sheet(isPresented: $showingInfoSheet) {
                InfoSheetView()
            }
            .navigationTitle("DaWarIch")
            .refreshable {
                bufferLength = locationHelper.traceBuffer.count
            }
        }
    }
}

struct InfoSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Information")
                    .font(.title)
                    .fontWeight(.bold)

                Text("• **Server Options**: Configure the server address (HTTP/HTTPS) and your API key for DaWarIch.\n\n• **Location Options**:\n   - Toggle tracking on/off.\n   - Force high-density location updates. This will start continuously getting the location, until you are stationary for a while.\n   - Enable or disable debug notifications.\n\n• **Buffer**: Shows how many location points are stored in memory. You can clear the buffer anytime.\n\n• **Send Options**: Configure how many data points to collect before sending to the server.")
                    .font(.body)

                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .padding(.top, 8)
            }
            .padding()
            .navigationTitle("About DaWarIch")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
