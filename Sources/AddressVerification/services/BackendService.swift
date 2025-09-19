//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 18/09/2025.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Backend Service
class BackendService {
    private let cache: GeoTagCache
    private let apiHelper: ApiHelper
    private var cancellables = Set<AnyCancellable>()

    
    init(cache: GeoTagCache, apiHelper: ApiHelper) {
        self.cache = cache
        self.apiHelper = apiHelper
    }
    
    /// Send completed schedules with attached geo-tags to backend
       func sendSchedules(_ schedules: [(Date, CLLocation)]) async {
           await withTaskGroup(of: Void.self) { group in
               for (schedule, location) in schedules {
                   group.addTask {
                       await self.handleSchedule(schedule, location: location)
                   }
               }
           }
       }

       /// Process and send one schedule
    private func handleSchedule(_ schedule: Date, location: CLLocation) async {
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let address = placemarks.first?.name ?? "Unknown address"

            let request = AddGeoTagRequest(
                address: address,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                deviceTimestamp: ISO8601DateFormatter().string(from: schedule)
            )

            try await sendGeoTag(request)
            print("✅ [BackendService] Sent schedule \(schedule) with address: \(address)")
        } catch {
            print("📥 [BackendService] Failed to send schedule \(schedule). Caching instead. Error: \(error)")

            // 🔹 Re-do reverse geocode for caching (or reuse last attempt if partial result available)
            var resolvedAddress = "Unknown address"
            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
                resolvedAddress = placemarks.first?.name ?? "Unknown address"
            } catch {
                print("⚠️ [BackendService] Reverse geocoding also failed, using fallback address")
            }

            let cached = CachedGeoTag(
                address: resolvedAddress,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                deviceTimestamp: ISO8601DateFormatter().string(from: schedule)
            )
            GeoTagCache.save(cached)
        }
    }

    
    // Equivalent to sendCachedGeoTags()
    func flushCachedGeoTags() async {
        let cachedTags = GeoTagCache.load()
        guard !cachedTags.isEmpty else { return }
        
        print("📦 [BackendService] Retrying \(cachedTags.count) cached geotags")
        
        var allSent = true
        for tag in cachedTags {
            let request = AddGeoTagRequest(
                address: tag.address,
                latitude: tag.latitude,
                longitude: tag.longitude,
                deviceTimestamp: tag.deviceTimestamp
            )
            
            do {
                try await sendGeoTag(request)
                print("✅ [BackendService] Cached tag sent")
            } catch {
                print("❌ [BackendService] Failed cached tag: \(error)")
                allSent = false
            }
        }
        
        if allSent {
            GeoTagCache.clear()
            print("🧹 [BackendService] Cleared cached geotags")
        }
    }
    
    // Equivalent to sendGeoTag()
    private func sendGeoTag(_ geoTag: AddGeoTagRequest) async throws -> AddGeoTagResponse {
        guard let credentials = StoredCredentials.load() else {
            throw NSError(
                domain: "BackendService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Missing stored credentials"]
            )
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AddGeoTagResponse, Error>) in
            apiHelper.addGeoTag(apiKey: credentials.apiKey, token: credentials.token, request: geoTag)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ [BackendService] Failed to send GeoTag: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { (response: AddGeoTagResponse) in
                        print("📍 [BackendService] GeoTag posted successfully: \(response)")
                        continuation.resume(returning: response)
                    }
                )
                .store(in: &cancellables)
        }
    }


}

