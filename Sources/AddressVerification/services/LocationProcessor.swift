//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/09/2025.
//

import Foundation
import CoreLocation


// MARK: - Location Processor
class LocationProcessor {
    private let scheduleManager: ScheduleManager
    private let locationCache: LocationCache
    private let backendService: BackendService
    private var completedSchedules: [(Date, CLLocation)] = []
    
    init(scheduleManager: ScheduleManager, locationCache: LocationCache, backendService: BackendService) {
        self.scheduleManager = scheduleManager
        self.locationCache = locationCache
        self.backendService = backendService
    }
    
    // Main entry point for handling new location updates
    func handleLocationUpdate(_ location: CLLocation) {
        print("\n🚦 [LocationProcessor] New location update received at \(location.timestamp)")
        
        // 1. Cache the latest location
        locationCache.cacheLocation(location)
        
        // 2. Check if it's within a schedule window
        if let matchedSchedule = scheduleManager.isWithinScheduleWindow(location.timestamp) {
            completedSchedules.append((matchedSchedule, location))
            print("🎯 [LocationProcessor] Matched location to schedule: \(matchedSchedule)")
            
            // Send immediately
            backendService.sendSchedules(completedSchedules)
            completedSchedules.removeAll()
        } else {
            print("🙅 [LocationProcessor] Location ignored (not within schedule window)")
        }
    }
    
    // Backfill when a schedule has passed without exact location
    func backfillSchedules(currentDate: Date) {
        let schedules = scheduleManager.getSchedules()
        
        for schedule in schedules {
            if schedule < currentDate && !completedSchedules.contains(where: { $0.0 == schedule }) {
                if let cachedLocation = locationCache.getLastLocation() {
                    completedSchedules.append((schedule, cachedLocation))
                    print("🔄 [LocationProcessor] Backfilled schedule \(schedule) with cached location")
                }
            }
        }
        
        if !completedSchedules.isEmpty {
            backendService.sendSchedules(completedSchedules)
            completedSchedules.removeAll()
        }
    }
}
