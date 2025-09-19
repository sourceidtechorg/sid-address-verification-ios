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
    private var sentSchedules: Set<Date> = [] // 🔑 track already sent
    
    init(scheduleManager: ScheduleManager, locationCache: LocationCache, backendService: BackendService) {
        self.scheduleManager = scheduleManager
        self.locationCache = locationCache
        self.backendService = backendService
    }
    
    // Main entry point for handling new location updates
    func handleLocationUpdate(_ location: CLLocation) async {
        print("\n🚦 [LocationProcessor] New location update received at \(location.timestamp)")
        
        // 1. Cache the latest location
        locationCache.cacheLocation(location)
        
        // 2. Check if it's within a schedule window
        if let matchedSchedule = scheduleManager.isWithinScheduleWindow(location.timestamp) {
            
            // ✅ Skip if already processed
            guard !sentSchedules.contains(matchedSchedule) else {
                print("⏩ [LocationProcessor] Schedule \(matchedSchedule) already sent, skipping")
                return
            }
            
            completedSchedules.append((matchedSchedule, location))
            sentSchedules.insert(matchedSchedule) // mark as sent
            print("🎯 [LocationProcessor] Matched location to NEW schedule: \(matchedSchedule)")
            
            // Send immediately
            await backendService.sendSchedules(completedSchedules)
            completedSchedules.removeAll()
        } else {
            print("🙅 [LocationProcessor] Location ignored (not within schedule window)")
        }
    }
    
    // Backfill when a schedule has passed without exact location
    func backfillSchedules(currentDate: Date) async {
        let schedules = scheduleManager.getSchedules()
        
        for schedule in schedules {
            if schedule < currentDate && !sentSchedules.contains(schedule) {
                if let cachedLocation = locationCache.getLastLocation() {
                    completedSchedules.append((schedule, cachedLocation))
                    sentSchedules.insert(schedule) // ✅ mark backfilled schedule as sent
                    print("🔄 [LocationProcessor] Backfilled schedule \(schedule) with cached location")
                }
            }
        }
        
        if !completedSchedules.isEmpty {
            await backendService.sendSchedules(completedSchedules)
            completedSchedules.removeAll()
        }
    }
}
