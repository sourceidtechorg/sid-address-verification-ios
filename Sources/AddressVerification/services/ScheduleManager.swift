//
//  ScheduleManager.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/09/2025.
//

import Foundation
import CoreLocation

// MARK: - Schedule Manager
class ScheduleManager {
    private var schedules: [Date] = []
    
    // Load and cache schedules upfront (from config or server)
    func loadSchedules(from config: [Date]) {
        self.schedules = config
        print("🗓️ [ScheduleManager] Loaded \(config.count) schedules: \(config)")
    }
    
    // Return schedules for external usage
    func getSchedules() -> [Date] {
        return schedules
    }
    
    // Check if current time falls within the window around any schedule
    func isWithinScheduleWindow(_ date: Date, windowMinutes: Int = 1) -> Date? {
        for schedule in schedules {
            let lowerBound = schedule.addingTimeInterval(TimeInterval(-windowMinutes * 60))
            let upperBound = schedule.addingTimeInterval(TimeInterval(windowMinutes * 60))
            
            if date >= lowerBound && date <= upperBound {
                print("✅ [ScheduleManager] \(date) is within window for schedule \(schedule)")
                return schedule
            }
        }
        print("⏱️ [ScheduleManager] \(date) is NOT within any schedule window")
        return nil
    }
}
