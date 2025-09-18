//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/09/2025.
//

import Foundation
import CoreLocation

// MARK: - Location Cache
class LocationCache {
    private var lastLocation: CLLocation?
    
    // Save a location in memory (fallback for missed updates)
    func cacheLocation(_ location: CLLocation) {
        self.lastLocation = location
        print("📍 [LocationCache] Cached location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    // Get last known location (for backfilling)
    func getLastLocation() -> CLLocation? {
        if let loc = lastLocation {
            print("📦 [LocationCache] Returning cached location: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        } else {
            print("⚠️ [LocationCache] No cached location available")
        }
        return lastLocation
    }
}
