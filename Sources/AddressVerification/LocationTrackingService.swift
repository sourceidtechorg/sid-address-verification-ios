//
//  File.swift
//  AddressVerification
//
//  Created by Richard Uzor on 24/06/2025.
//

import Foundation
import CoreLocation
import BackgroundTasks
import Combine
import UserNotifications // Added for local notifications


@available(macOS 11.0, iOS 13.0, *)
@MainActor


class LocationTrackingService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingService()
    
    private var locationManager: CLLocationManager?
    private var cancellables = Set<AnyCancellable>()
    
    private let apiHelper = ApiHelper()
    private let geoTagCache = GeoTagCache()
    private var apiKey = ""
    private var customerID = ""
    private var verificationGroupID = ""
    private var token = ""
    private var refreshToken = ""
    
    
    // Inject our modular components
      private let scheduleManager: ScheduleManager
      private let locationCache: LocationCache
      private let backendService: BackendService
      private let processor: LocationProcessor
      
      override init() {
          // Setup managers
          self.scheduleManager = ScheduleManager()
          self.locationCache = LocationCache()
          self.backendService = BackendService(cache: geoTagCache, apiHelper: apiHelper)
          self.processor = LocationProcessor(
              scheduleManager: scheduleManager,
              locationCache: locationCache,
              backendService: backendService
          )
          
          super.init()
          
          
          self.locationManager = CLLocationManager()

          
          // Configure CLLocationManager
          if let locationManager = locationManager {
              locationManager.delegate = self
              
              locationManager.desiredAccuracy = kCLLocationAccuracyBest
              locationManager.allowsBackgroundLocationUpdates = true
              locationManager.pausesLocationUpdatesAutomatically = false
          }

          
          print("🚀 [LocationService] Initialized")
      }
    
//    private var customerID: String = ""
    private var isGeotaggingActive = false
    
    private let isSimpleTestMode = false  // Set to false for production
    private let testIntervalSeconds = 10.0
    private let testTotalIterations = 12  // 12 iterations = 2 minutes
    private let isTestingMode = false  // Set to false for production
    
    
    
    // Request permissions
        func requestAuthorization() {
            locationManager?.requestAlwaysAuthorization()
            print("🔑 [LocationService] Requested Always Authorization")
        }
        
        // Start location updates
    func startTracking(apiKey: String, customerID: String, verificationGroupId: String, token: String, refreshToken: String) async {
            self.apiKey = apiKey
        self.customerID = customerID
        self.verificationGroupID = verificationGroupId
            self.token = token
            self.refreshToken = refreshToken
            
        StoredCredentials.save(apiKey: apiKey, customerID: customerID, verificationGroupId: verificationGroupId,token: token, refreshToken: refreshToken)
            requestAuthorization()
        await startGeotagging()
            
            locationManager?.startUpdatingLocation()
            print("▶️ [LocationService] Started location tracking")
        }
    
    // MARK: - Public entry
       func startGeotagging() async {
           guard !isGeotaggingActive else {
               print("⚠️ [LocationTrackingService] Geotagging already active")
               return
           }
           
           isGeotaggingActive = true
//           isTestingMode = isTesting
           defer { isGeotaggingActive = false }
           
           // Step 1: Fetch config
           guard let config = await fetchOrgConfig() else {
               print("❌ [LocationTrackingService] Failed to fetch org config")
               return
           }
           
           // Step 2: Fetch pending address
           guard let address = await fetchPendingAddress() else {
               print("ℹ️ [LocationTrackingService] No pending verification")
               return
           }
           
           // Step 3: Build schedule timestamps
           let lastTimestamp = address.metadata.locations
               .compactMap { ISO8601DateFormatter().date(from: $0.timestamp) }
               .max() ?? Date()
           
           let intervalSeconds: Double
           let sessionDurationSeconds: Double
           
           /*if isTestingMode {
               intervalSeconds = 10.0
               sessionDurationSeconds = 120.0
               print("🧪 [LocationTrackingService] TESTING MODE (10s interval, 2m session)")
           } else {*/
               intervalSeconds = config.geotaggingPollingInterval * 3600
               sessionDurationSeconds = Double(config.geotaggingSessionTimeout) * 86400
               print("🏭 [LocationTrackingService] PRODUCTION MODE")
//           }
           
           let now = Date().timeIntervalSince1970
           var current = lastTimestamp.timeIntervalSince1970
           let end = current + sessionDurationSeconds
           
           var timestamps: [Date] = []
           while current <= end {
               if current > now {
                   timestamps.append(Date(timeIntervalSince1970: current))
               }
               current += intervalSeconds
           }
           
           print("🗓️ [LocationTrackingService] Generated \(timestamps.count) schedule(s)")
           
           // Step 4: Load into ScheduleManager
           scheduleManager.loadSchedules(from: timestamps)
           
           // From here, CoreLocation updates will drive processing
           print("🚀 [LocationTrackingService] Geotagging session started. Waiting for location updates...")
       }
        
        // Stop location updates
        func stopTracking() {
            locationManager?.stopUpdatingLocation()
            print("⏹️ [LocationService] Stopped location tracking")
        }
        
        // Load schedules into ScheduleManager
        func loadSchedules(_ schedules: [Date]) {
            scheduleManager.loadSchedules(from: schedules)
        }
        
        // CLLocationManagerDelegate - new location update
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let latestLocation = locations.last else { return }
            print("📡 [LocationService] Received new location: \(latestLocation.coordinate.latitude), \(latestLocation.coordinate.longitude)")
            
            // Forward to processor
        Task {
               await processor.handleLocationUpdate(latestLocation)
           }
        }
        
        // CLLocationManagerDelegate - error handling
        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("❌ [LocationService] Location update failed: \(error.localizedDescription)")
        }
        
        // Trigger manual backfill (e.g., when app resumes or timer fires)
    func backfillIfNeeded() async {
            let now = Date()
        await processor.backfillSchedules(currentDate: now)
        }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 [LocationService] Authorization changed: \(status.rawValue)")

        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            print("✅ Permission granted, starting updates")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("❌ Permission denied or restricted")
        case .notDetermined:
            print("🤔 Permission not determined yet")
        @unknown default:
            break
        }
    }

    
    
    private func fetchOrgConfig() async -> OrganisationConfigData? {
        
        await withCheckedContinuation { continuation in
            print("api key: \(apiKey)")
            apiHelper.fetchOrganisationConfig(apiKey: apiKey)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Org config fetch error: \(error)")
                        continuation.resume(returning: nil)
                    }
                }, receiveValue: { response in
                    continuation.resume(returning: response.data)
                })
                .store(in: &cancellables)
        }
    }
    
    private func fetchPendingAddress() async -> CustomerData? {
        await withCheckedContinuation { continuation in
            apiHelper.fetchCustomerHistory(apiKey: apiKey, customerID: customerID, verificationGroupId: verificationGroupID)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Customer history fetch error: \(error)")
                        continuation.resume(returning: nil)
                    }
                }, receiveValue: { response in
                    let pending = response.data.first { $0.verificationStatus == "pending" }
                    continuation.resume(returning: pending)
                })
                .store(in: &cancellables)
        }
    }
    
}
