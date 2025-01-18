//
//  LocationHelper.swift
//  DaWarIch Companion
//
//  Created by yniverz on 17.01.25.
//

import Foundation
import CoreLocation
import UserNotifications
import UIKit
import Network

class LocationHelper: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    private let maximumPositionAccuracy: Double = 50 // meters
    private let regionTimeoutRadius: Double = 20 // meters
    private let positionUpdateTimeout: Double = 60*1 // seconds
    private let minDistanceBeforeSave: Double = 15 // meters: less than this, skip entirely
    
    private var lastMovedThreshhold: Date?
    private var updatesRunning = false
    private var stopUpdates = false
    
    private var writingQueue = DispatchQueue(label: "writingQueue")
    private var loopStartQueue = DispatchQueue(label: "loopStartQueue")
    private var networkMonitorQueue = DispatchQueue(label: "networkMonitorQueue")
    
    var isNetworkReachable: Bool = false
    
    //set default values for configuration parameters (overwritten in init block)
    @Published var authorisationStatus: CLAuthorizationStatus = .notDetermined
    
    
    var dawarichServerHost: String {
        set {
            UserDefaults.standard.set(newValue, forKey: "dawarichServerHost")
        }
        get {
            UserDefaults.standard.string(forKey: "dawarichServerHost") ?? ""
        }
    }
    var dawarichServerKey: String {
        set {
            UserDefaults.standard.set(newValue, forKey: "dawarichServerKey")
        }
        get {
            UserDefaults.standard.string(forKey: "dawarichServerKey") ?? ""
        }
    }
    
    var trackingActivated: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: "trackingActivated")
            if newValue {
                start()
            }
        }
        get {
            UserDefaults.standard.bool(forKey: "trackingActivated")
        }
    }
    var alwaysHighDensity: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: "alwaysHighDensity")
        }
        get {
            UserDefaults.standard.bool(forKey: "alwaysHighDensity")
        }
    }
    
    var debugNotifications: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: "debugNotifications")
            if newValue {
                sendNotification("Notifications activated.")
            }
        }
        get {
            UserDefaults.standard.bool(forKey: "debugNotifications")
        }
    }
    
    var selectedMaxBufferSize: Int {
        set {
            UserDefaults.standard.set(newValue, forKey: "selectedMaxBufferSize")
        }
        get {
            UserDefaults.standard.integer(forKey: "selectedMaxBufferSize")
        }
    }
    
    
    var traceBuffer: [LocationItem] {
        set {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(newValue)
                UserDefaults.standard.set(data, forKey: "traceBuffer")
                print("saved lastLocationItem")
            } catch {
                print("Failed to encode lastLocationItem: \(error)")
            }
        }
        get {
            do {
                if let data = UserDefaults.standard.data(forKey: "traceBuffer") {
                    let decoder = JSONDecoder()
                    return try decoder.decode([LocationItem].self, from: data)
                } else {
                    print("No traceBuffer found in UserDefaults.")
                }
            } catch {
                print("Failed to decode traceBuffer: \(error)")
            }
            
            return []
        }
    }
    
    override
    init() {
//        mapProgress = MapProgressTracker(storageManager)
        super.init()
        
//        loadLocationTrace()
        
        //set up CLLocationManager to send us location updates continously (while active)
        self.locationManager.delegate = self
        self.locationManager.allowsBackgroundLocationUpdates = true
        self.locationManager.pausesLocationUpdatesAutomatically = false
        self.locationManager.distanceFilter = 100
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("Internet connection is available.")
                self.sendNotification("Network Available")
                self.isNetworkReachable = true
                // Perform actions when internet is available
            } else {
                print("Internet connection is not available.")
                self.sendNotification("Network Unvailable")
                self.isNetworkReachable = false
                // Perform actions when internet is not available
            }
        }
        monitor.start(queue: networkMonitorQueue)
        
        if trackingActivated {
            self.start()
        }
    }
    
    
    public func start() {
        self.requestAuth()
        
        self.locationManager.startUpdatingLocation()
        self.locationManager.startMonitoringSignificantLocationChanges()
//        self.locationManager.startMonitoringVisits()
        
        startLoop()
    }
    
    public func startLoop() {
        
        loopStartQueue.async {
            if !self.trackingActivated {
                return
            }
            
            if !self.alwaysHighDensity {
                return
            }
            
            print("Scheduling start live Service")
            
            if !self.updatesRunning {
                self.stopUpdates = false
                self.updatesRunning = true
                
                Task() {
                    self.lastMovedThreshhold = Date()
                    
                    print("Starting live Service")
                    await self.livePositionLoop()
                    
                    self.updatesRunning = false
                }
            }
        }
    }
    
    public func stop(){
        self.locationManager.stopUpdatingLocation()
        self.locationManager.stopMonitoringSignificantLocationChanges()
        self.locationManager.stopMonitoringVisits()
        self.stopUpdates = true
    }
    
    //get the initial authorization to access device location
    public func requestAuth() {
        if self.authorisationStatus != .authorizedAlways {
//            self.locationManager.requestWhenInUseAuthorization()
            self.locationManager.requestAlwaysAuthorization()
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notification permissions granted!")
            } else if let error {
                print(error.localizedDescription)
            }
        }
    }
    
    func livePositionLoop() async {
        
        do {
            
            let updates = CLLocationUpdate.liveUpdates()
            
            let startTime = Date()
            self.lastMovedThreshhold = nil
            var lastMovedLocation: CLLocation? = nil
            for try await update in updates {
                if self.stopUpdates || !trackingActivated {
                    self.stopUpdates = false
                    break
                }
                
                if let location = update.location {
                    
                    if lastMovedLocation.isNil || self.lastMovedThreshhold.isNil || location.speed * 3.6 >= 10 || location.distance(from: lastMovedLocation!) >= regionTimeoutRadius {
                        lastMovedLocation = location
                        self.lastMovedThreshhold = Date()
                    }
                    
                    print(location)
                        
                    if location.timestamp > self.lastMovedThreshhold!.addingTimeInterval(positionUpdateTimeout) {
                        print("Logged for ", Date().timeIntervalSince(startTime), "Seconds")
                        break
                    }
                    
                    self.locationManager(didUpdateLocation: location)
                }
            }
            
            sendToServer()
        } catch {
            print("Could not start location updates")
        }
    }
    
}






extension LocationHelper: CLLocationManagerDelegate {
    var lastLocationItem: LocationItem? {
        set {
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(newValue)
                UserDefaults.standard.set(data, forKey: "lastLocationItem")
                print("saved lastLocationItem")
            } catch {
                print("Failed to encode lastLocationItem: \(error)")
            }
        }
        get {
            do {
                if let data = UserDefaults.standard.data(forKey: "lastLocationItem") {
                    let decoder = JSONDecoder()
                    return try decoder.decode(LocationItem.self, from: data)
                } else {
                    print("No lastLocationItem found in UserDefaults.")
                }
            } catch {
                print("Failed to decode lastLocationItem: \(error)")
            }
            return nil
        }
    }

    //update auth status whenever it changes
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorisationStatus = status
    }
    
    //MAIN LOCATION UPDATE FUNCTION
    //iOS calls this function WHENEVER it passes a new location to the location manager.
    //We use this function to parse the incoming data and log it directly to Core Data
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !updatesRunning {
            for newLocation in locations {
                self.locationManager(didUpdateLocation: newLocation)
            }
            sendNotification("You Moved Signifficantly.")
        }
        
        startLoop()
    }
    
    private func locationManager(didUpdateLocation location: CLLocation) {
        writingQueue.async {
            if location.horizontalAccuracy > self.maximumPositionAccuracy {
                return
            }
            
            let newItem = self.getLocationItemFromCLLocation(location)
            
            if let lastLocation = self.lastLocationItem {
                if lastLocation.time >= newItem.time || lastLocation.location.distance(from: newItem.location).magnitude < self.minDistanceBeforeSave {
                    return
                }
            }
            
            self.traceBuffer.append(newItem)
            
            self.lastLocationItem = newItem
            
            if self.traceBuffer.count >= self.selectedMaxBufferSize {
                self.sendToServer()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
//        if visit.departureDate != .distantFuture && visit.arrivalDate != .distantPast {
//            writingQueue.async {
//                self.storageManager.addVisitItem(visit)
//            }
//        }
        
        if visit.departureDate == .distantFuture {
            return
        }
        
        sendNotification("You left a Location.")
        
        startLoop()
    }
    
    //if the location manager failed for whatever reason, give up and log to console
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("ERROR - No Location Received")
    }
    
    
    func addVisitItem(_ item: CLVisit) {
        
    }
    
    
    
    func sendNotification(_ message: String, title: String? = nil) {
        if !debugNotifications {
            return
        }
        
        print("sending notification: \(message)")
        let content = UNMutableNotificationContent()
        content.title = "DaWarIch"
        if !title.isNil && title!.isEmpty {
            content.title = "DaWarIch - " + title!
        }
        content.body = message
        content.sound = UNNotificationSound.default
        
        // show this notification five seconds from now
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    
    
    func sendToServer() {
        if !isNetworkReachable {
            return
        }
        
    //    {
    //      "locations": [
    //        {
    //          "type": "Feature",
    //          "geometry": {
    //            "type": "Point",
    //            "coordinates": [
    //              13.356718,
    //              52.502397
    //            ]
    //          },
    //          "properties": {
    //            "timestamp": "2021-06-01T12:00:00Z",
    //            "altitude": 0,
    //            "speed": 0,
    //            "horizontal_accuracy": 0,
    //            "vertical_accuracy": 0,
    //            "motion": [],
    //            "pauses": false,
    //            "activity": "unknown",
    //            "desired_accuracy": 0,
    //            "deferred": 0,
    //            "significant_change": "unknown",
    //            "locations_in_payload": 1,
    //            "device_id": "Swagger",
    //            "wifi": "unknown",
    //            "battery_state": "unknown",
    //            "battery_level": 0
    //          }
    //        }
    //      ]
    //    }
        // 1. Make sure we have something to send and a valid host
        guard !traceBuffer.isEmpty,
              !dawarichServerHost.isEmpty,
              let url = URL(string: dawarichServerHost + "/api/v1/overland/batches?api_key=\(dawarichServerKey)")
        else {
            print("No data to send or invalid server host.")
            return
        }

        // 2. Construct data structures that match the expected JSON
        struct OverlandFeatureCollection: Encodable {
            let locations: [OverlandFeature]
        }
        
        struct OverlandFeature: Encodable {
            let type = "Feature"
            let geometry: OverlandGeometry
            let properties: OverlandProperties
        }
        
        struct OverlandGeometry: Encodable {
            let type = "Point"
            let coordinates: [Double]  // [longitude, latitude]
        }
        
        struct OverlandProperties: Encodable {
            let timestamp: String
            let altitude: Double
            let speed: Double
            let horizontal_accuracy: Double
            let vertical_accuracy: Double
            let motion: [String]
            let pauses: Bool
            let activity: String
            let desired_accuracy: Double
            let deferred: Double
            let significant_change: String
            let locations_in_payload: Int
            let device_id: String
            let wifi: String
            let battery_state: String
            let battery_level: Double
        }

        // 3. Map traceBuffer into our OverlandFeatureCollection
        var features: [OverlandFeature] = []
        let dateFormatter = ISO8601DateFormatter()
        // You can also use something else as device ID, e.g. the serverKey, UUID, or a fixed string.
        let deviceID = UIDevice.current.name
        
        for item in traceBuffer {
            let date = Date(timeIntervalSince1970: item.time)
            let isoTime = dateFormatter.string(from: date)
            
            let geometry = OverlandGeometry(
                coordinates: [item.lng, item.lat] // GeoJSON expects [lon, lat]
            )
            
            let properties = OverlandProperties(
                timestamp: isoTime,
                altitude: item.alt,
                speed: item.spd * 3.6,
                horizontal_accuracy: item.horAcc,
                vertical_accuracy: item.altAcc,
                motion: [],               // or fill in actual motion info
                pauses: false,
                activity: "unknown",      // or fill in if you track user activity
                desired_accuracy: 0,
                deferred: 0,
                significant_change: "unknown",
                locations_in_payload: 1,
                device_id: deviceID,
                wifi: "unknown",
                battery_state: "unknown",
                battery_level: 0
            )
            
            let feature = OverlandFeature(
                geometry: geometry,
                properties: properties
            )
            
            features.append(feature)
        }
        
        let featureCollection = OverlandFeatureCollection(locations: features)
        
        // 4. Encode the feature collection to JSON
        guard let jsonData = try? JSONEncoder().encode(featureCollection) else {
            print("Error encoding feature collection.")
            return
        }
        
        // 5. Create and configure the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // If your server expects Bearer token with your server key:
        if !dawarichServerKey.isEmpty {
            request.setValue("Bearer \(dawarichServerKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = jsonData
        
        // 6. Send the data (URLSession background tasks or async/await are also possible)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle networking errors
            if let error = error {
                print("Error sending data to server: \(error.localizedDescription)")
                return
            }
            
            // Handle HTTP status codes
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("Server responded with status code: \(httpResponse.statusCode)")
                    sendNotification("\(httpResponse)", title: "HTTP Err")
                    return
                }
            }
            
            // Optionally parse `data` if server returns details
            print("Data successfully sent to server and local buffer will be cleared.")
            clearBuffer()
        }
        task.resume()
    }
    
    
    
    func clearBuffer() {
        writingQueue.async {
            self.traceBuffer = []
        }
    }
    
    
    // ##############
    // HELPERS
    // ##############
    
    func getLocationItemFromCLLocation(_ location: CLLocation) -> LocationItem {
        return LocationItem(time: location.timestamp.timeIntervalSince1970.magnitude,
                            lat: location.coordinate.latitude,
                            lng: location.coordinate.longitude,
                            horAcc: location.horizontalAccuracy,
                            alt: location.altitude,
                            altAcc: location.verticalAccuracy,
                            floor: location.floor?.level ?? 0,
                            hdg: location.course,
                            hdgAcc: location.courseAccuracy,
                            spd: location.speed,
                            spdAcc: location.speedAccuracy)
    }
}
