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
    func startTracking(apiKey: String, customerID: String, token: String, refreshToken: String) async {
            self.apiKey = apiKey
        self.customerID = customerID
            self.token = token
            self.refreshToken = refreshToken
            
        StoredCredentials.save(apiKey: apiKey, customerID: customerID, token: token, refreshToken: refreshToken)
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
            apiHelper.fetchCustomerHistory(apiKey: apiKey, customerID: customerID)
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
    
    /*private func postCurrentLocation() async {
        guard CLLocationManager.locationServicesEnabled() else {
            print("Location services disabled")
            return
        }
        
        // Request one-time location if needed
        if locationManager.location == nil {
            locationManager.requestLocation()
            // Wait a bit for location to be available
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        guard let location = locationManager.location else {
            print("No current location available")
            return
        }
        
        let geocoder = CLGeocoder()
        let coordinate = location.coordinate
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let address = placemarks.first?.name ?? "Unknown address"
            let timestamp = ISO8601DateFormatter().string(from: Date())
            
            
            let request = AddGeoTagRequest(
                address: address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                deviceTimestamp: timestamp
            )
            
            
            if isConnectedToInternet() {
                await sendCachedGeoTags()
                do {
                    let success = try await sendGeoTag(geoTag: request, token: token)
                    if success {
                        print("✅ GeoTag sent successfully")
                        showTrackingNotification() // Show periodic notification
                    }
                } catch {
                    print("Error sending current geotag: \(error)")
                    let cached = CachedGeoTag(
                        address: address,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        deviceTimestamp: timestamp
                    )
                    GeoTagCache.save(cached)
                }
            } else {
                print("📥 No internet. Caching geotag.")
                let cached = CachedGeoTag(
                    address: address,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    deviceTimestamp: timestamp
                )
                GeoTagCache.save(cached)
            }
            
            
        } catch {
            print("Reverse geocode failed: \(error)")
        }
    }*/
    
    /*private func sendCachedGeoTags() async {
        let cachedTags = GeoTagCache.load()
        guard !cachedTags.isEmpty else { return }
        
        var allSent = true
        
        for tag in cachedTags {
            let request = AddGeoTagRequest(
                address: tag.address,
                latitude: tag.latitude,
                longitude: tag.longitude,
                deviceTimestamp: tag.deviceTimestamp
            )
            
            let result = await withCheckedContinuation { continuation in
                apiHelper.addGeoTag(apiKey: apiKey, token: token, request: request)
                    .sink(receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("❌ Failed cached geotag: \(error)")
                            continuation.resume(returning: false)
                        }
                    }, receiveValue: { _ in
                        print("✅ Cached geotag sent")
                        continuation.resume(returning: true)
                    })
                    .store(in: &cancellables)
            }
            
            if !result {
                allSent = false
                break
            }
        }
        
        if allSent {
            GeoTagCache.clear()
            print("🧹 Cleared cached geotags")
        }
    }*/
    
    /*private func sendGeoTag(geoTag: AddGeoTagRequest, token: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            apiHelper.addGeoTag(apiKey: apiKey, token: token, request: geoTag)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: error)
                    }
                }, receiveValue: { response in
                    print("📍 GeoTag posted: \(response)")
                    continuation.resume(returning: true)
                })
                .store(in: &cancellables)
        }
    }*/
    
    
    
    
    /*func stop() {
        isGeotaggingActive = false
        
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        cancellables.removeAll()
        print("🛑 Geotagging stopped")
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["LocationTracking"])
        
    }*/
    
    /*func scheduleBackgroundGeotagTask() {
#if os(iOS)
        // Cancel any existing tasks first
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "tech.sourceid.addressverification.geotag")
        
        let request = BGProcessingTaskRequest(identifier: "tech.sourceid.addressverification.geotag")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        // Set earliest begin date to avoid immediate scheduling
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60) // 15 minutes from now
        
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📆 Background geotag task scheduled for: \(request.earliestBeginDate?.description ?? "unknown")")
            
        } catch {
            print("❌ Failed to schedule background task: \(error)")
            handleBackgroundTaskSchedulingError(error)
        }
#else
        print("⚠️ Background task scheduling is only supported on iOS.")
#endif
    }*/
    
    /*#if os(iOS)
    private func handleBackgroundTaskSchedulingError(_ error: Error) {
        if let bgError = error as? BGTaskScheduler.Error {
            switch bgError.code {
            case .unavailable:
                print("❌ Background tasks unavailable (simulator or device restrictions)")
            case .tooManyPendingTaskRequests:
                print("❌ Too many pending background tasks")
            case .notPermitted:
                print("❌ Background tasks not permitted for this app")
            @unknown default:
                print("❌ Unknown background task error: \(bgError)")
            }
        }
    }
#endif*/
    
    /*#if os(iOS)
    func handleBackgroundGeotagTask(task: BGProcessingTask) {
        print("📦 Background geotag task started")
        
        var taskWasCancelled = false
        
        task.expirationHandler = {
            print("⏳ Geotag task expired before completion.")
            taskWasCancelled = true
            self.isGeotaggingActive = false
            
        }
        
        guard let creds = StoredCredentials.load() else {
            print("❌ Missing stored credentials")
            task.setTaskCompleted(success: false)
            return
        }
        
        self.apiKey = creds.apiKey
        self.token = creds.token
        self.refreshToken = creds.refreshToken
        
        
        Task {
            await self.runScheduledGeoTagging()
            
            if taskWasCancelled {
                print("🛑 Task was cancelled before finishing.")
                task.setTaskCompleted(success: false)
                return
            }
            
            task.setTaskCompleted(success: true)
            self.scheduleBackgroundGeotagTask() // Schedule next session
        }
    }
#endif*/
    
    // MARK: - CLLocationManagerDelegate
    /*func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Handle location updates if needed
        print("📍 Location updated: \(locations.last?.coordinate.longitude.description ?? "unknown")")
        Task {
            await postCurrentLocation()
            if isGeotaggingActive {
                await runScheduledGeoTagging() // Restart geotagging on significant location change
            }
        }
    }*/
    
    /* func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error)")
    }*/
    
    /* func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 Location authorization changed: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways:
            print("✅ Got Always permission - configuring location manager")
            configureLocationManager()
            
        case .authorizedWhenInUse:
            print("⚠️ Only got When-In-Use permission - requesting Always...")
            // Don't automatically request again here, let the async method handle it
            
        case .denied, .restricted:
            print("❌ Location access denied/restricted. Background tracking unavailable.")
            stop()
            
        case .notDetermined:
            print("🤔 Permission still not determined")
            
        @unknown default:
            print("⚠️ Unknown authorization status: \(status.rawValue)")
        }
    }*/
    
}
