//
//  Models.swift
//  DaWarIch Companion
//
//  Created by yniverz on 17.01.25.
//

import Foundation
import CoreLocation

struct LocationItem: Codable, Hashable {
    var time: Double
    var lat: Double
    var lng: Double
    var horAcc: Double
    var alt: Double
    var altAcc: Double
    var floor: Int
    var hdg: Double
    var hdgAcc: Double
    var spd: Double
    var spdAcc: Double
    
    var date: Date {
        Date(timeIntervalSince1970: time)
    }
    
    var coordinates: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    var location: CLLocation {
        CLLocation(latitude: lat, longitude: lng)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(time)
    }

    static func == (lhs: LocationItem, rhs: LocationItem) -> Bool {
        return lhs.time == rhs.time && lhs.lat == rhs.lat && lhs.lng == rhs.lng
    }
    
    static let allZero = LocationItem(time: 0, lat: 0, lng: 0, horAcc: 0, alt: 0, altAcc: 0, floor: 0, hdg: 0, hdgAcc: 0, spd: 0, spdAcc: 0)
}