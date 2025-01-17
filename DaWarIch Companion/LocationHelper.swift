//
//  LocationHelper.swift
//  DaWarIch Companion
//
//  Created by yniverz on 17.01.25.
//

import Foundation
import CoreLocation
import UserNotifications

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
    
    //set default values for configuration parameters (overwritten in init block)
    @Published var authorisationStatus: CLAuthorizationStatus = .notDetermined
    
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
            sendNotification("You Signifficantly moved.")
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
    
    
    
    func sendNotification(_ message: String, title: String = "DaWarIch") {
        print("sending \(message)")
        let content = UNMutableNotificationContent()
        content.title = "Notification title"
        content.subtitle = "Notification subtitle"
        content.body = "Notification body"
        content.sound = UNNotificationSound.default
        
        // show this notification five seconds from now
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
