//
//  ContentView.swift
//  DaWarIch Companion
//
//  Created by yniverz on 17.01.25.
//

import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        TabView {
            HomepageView()
                .tabItem {
                    Label("Settings", systemImage: "map")
                }
            TrackerSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        // A container view that holds the toolbar and WKWebView
        let containerView = UIView()
        
        // Create the toolbar at the top
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        // Create Back and Forward buttons using SF Symbols
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.goBack)
        )
        
        let forwardButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.goForward)
        )
        
        // Create a fixed space between the back and forward buttons
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixedSpace.width = 20
        
        // Create a flexible space to push the reload button to the right
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // Create a Reload button
        let reloadButton = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: context.coordinator,
            action: #selector(Coordinator.reloadPage)
        )
        
        // Initially disable Back/Forward until we know the web view's state
        backButton.isEnabled = false
        forwardButton.isEnabled = false
        
        // Assign references to the coordinator
        context.coordinator.backButton = backButton
        context.coordinator.forwardButton = forwardButton
        
        // Add the items to the toolbar
        toolbar.items = [backButton, fixedSpace, forwardButton, flexibleSpace, reloadButton]
        
        // Create the WKWebView
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Observe URL changes via KVO
        context.coordinator.observeWebView(webView)
        
        // Add subviews
        containerView.addSubview(toolbar)
        containerView.addSubview(webView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Toolbar at the top
            toolbar.topAnchor.constraint(equalTo: containerView.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Web view fills the remaining space
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        
        // Load the initial URL
        if let url = URL(string: url) {
            webView.load(URLRequest(url: url))
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No dynamic updates for this example
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        
        // Keep references to the toolbar items so we can enable/disable them
        weak var backButton: UIBarButtonItem?
        weak var forwardButton: UIBarButtonItem?
        
        // Keep a reference to the WKWebView itself
        private(set) weak var webView: WKWebView?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // MARK: - Observe WebView
        func observeWebView(_ webView: WKWebView) {
            self.webView = webView
            
            // Observe changes to the 'url' property
            webView.addObserver(
                self,
                forKeyPath: #keyPath(WKWebView.url),
                options: [.new],
                context: nil
            )
        }
        
        deinit {
            // Remove observer to avoid crashes
            webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        }
        
        // KVO callback
        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            guard keyPath == #keyPath(WKWebView.url),
                  let webView = object as? WKWebView else {
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
                return
            }
            
            // Whenever the URL changes (including JS changes), update button states.
            updateNavigationButtonsState(for: webView)
        }
        
        // MARK: - Button Actions
        @objc func goBack() {
            webView?.goBack()
            updateNavigationButtonsState(for: webView!)
        }
        
        @objc func goForward() {
            webView?.goForward()
            updateNavigationButtonsState(for: webView!)
        }
        
        @objc func reloadPage() {
            webView?.reload()
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            updateNavigationButtonsState(for: webView)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateNavigationButtonsState(for: webView)
        }
        
        // MARK: - Helper
        private func updateNavigationButtonsState(for webView: WKWebView) {
            backButton?.isEnabled = webView.canGoBack
            forwardButton?.isEnabled = webView.canGoForward
        }
    }
}

struct HomepageView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    var locationHelper: LocationHelper {
        appDelegate.locationHelper
    }
    
    var body: some View {
        if locationHelper.dawarichServerHost.isEmpty {
            Text("Please add a Server Host in the Settings first.")
        } else {
            WebView(url: locationHelper.dawarichServerHost)
        }
    }
}


struct TrackerSettingsView: View {
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
