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
    
    private var customerID: String = ""
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
    func startTracking(apiKey: String, token: String, refreshToken: String) async {
            self.apiKey = apiKey
            self.token = token
            self.refreshToken = refreshToken
            
            StoredCredentials.save(apiKey: apiKey, token: token, refreshToken: refreshToken)
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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) async {
            guard let latestLocation = locations.last else { return }
            print("📡 [LocationService] Received new location: \(latestLocation.coordinate.latitude), \(latestLocation.coordinate.longitude)")
            
            // Forward to processor
        await processor.handleLocationUpdate(latestLocation)
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
    
    
//    override init() {
//        super.init()
//        locationManager = CLLocationManager()
//        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyBest
//        locationManager.allowsBackgroundLocationUpdates = true
//        locationManager.pausesLocationUpdatesAutomatically = false
//        
//        // Check initial capabilities
//        checkSystemCapabilities()
//        
//        
//        // Request notification permissions
//        requestNotificationPermissions()
//    }
    
    /*private func checkSystemCapabilities() {
        print("🔍 System Capabilities Check:")
        print("   - Location Services Enabled: \(CLLocationManager.locationServicesEnabled())")
        //        print("   - Background App Refresh Available: \(UIApplication.shared.backgroundRefreshStatus.rawValue)")
        print("   - Current Authorization: \(locationManager.authorizationStatus.rawValue)")
        
#if targetEnvironment(simulator)
        print("   - Running on Simulator: YES (Background tasks limited)")
#else
        print("   - Running on Device: YES")
#endif
    }*/
    
    /*private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("❌ Failed to request notification permissions: \(error)")
            }
        }
    }*/
    
    /*private func showTrackingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Address Verification"
        content.body = "Sending location updates for verification..."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "LocationTracking", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show notification: \(error)")
            } else {
                print("🔔 Tracking notification displayed")
            }
        }
    }*/
    
    /*func start(apiKey: String, token: String, refreshToken: String) {
        self.apiKey = apiKey
        self.token = token
        self.refreshToken = refreshToken
        
        StoredCredentials.save(apiKey: apiKey, token: token, refreshToken: refreshToken)
        
        print("🚀 Starting LocationTrackingService...")
        print("   - API Key: \(apiKey.prefix(20))...")
        
        // Show notification to indicate service is running
        showTrackingNotification()
        
        //           print("   - Customer ID: \(customerID)")
        
        //
        //        locationManager.allowsBackgroundLocationUpdates = true
        //          locationManager.pausesLocationUpdatesAutomatically = false
        //          locationManager.startMonitoringSignificantLocationChanges()
        
        // Request location permissions first
        //        requestLocationPermissions()
        
        Task {
            await requestLocationPermissions()
            
            await self.runScheduledGeoTagging()
            scheduleBackgroundGeotagTask()
        }
        
        
    }*/
    
    /*private func requestLocationPermissions() async {
        print("🔐 Requesting location permissions...")
        print("   Current status: \(locationManager.authorizationStatus.rawValue)")
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("📱 Requesting Always authorization...")
            locationManager.requestAlwaysAuthorization()
            
            // Wait for permission response
            await waitForPermissionResponse()
            
        case .authorizedWhenInUse:
            print("⬆️ Upgrading from When-In-Use to Always...")
            locationManager.requestAlwaysAuthorization()
            
            // Wait for permission response
            await waitForPermissionResponse()
            
        case .authorizedAlways:
            print("✅ Already have Always permission")
            configureLocationManager()
            
        case .denied, .restricted:
            print("❌ Location permission denied/restricted. Background tracking unavailable.")
            
        @unknown default:
            print("⚠️ Unknown location authorization status")
        }
    }*/
    
    /* private func waitForPermissionResponse() async {
        // Wait up to 10 seconds for user to respond to permission dialog
        for _ in 0..<100 {
            if locationManager.authorizationStatus != .notDetermined {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Configure if we got the right permission
        if locationManager.authorizationStatus == .authorizedAlways {
            configureLocationManager()
        } else {
            print("❌ Did not receive Always location permission (got: \(locationManager.authorizationStatus.rawValue))")
        }
    }*/
    
    
    /*private func configureLocationManager() {
        guard locationManager.authorizationStatus == .authorizedAlways else {
            print("❌ Always location permission required for background tracking")
            return
        }
        
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startUpdatingLocation()
        
        
        // Schedule the first background task
        scheduleBackgroundGeotagTask()
    }*/
    
    
    /*private func runScheduledGeoTagging() async {
        guard !isGeotaggingActive else {
            print("⚠️ Geotagging session already active")
            return
        }
        
        isGeotaggingActive = true
        defer { isGeotaggingActive = false }
        
        // Step 1: Fetch org config
        let orgConfig = await fetchOrgConfig()
        guard let config = orgConfig else {
            print("Failed to fetch org config")
            return
        }
        
        // Step 2: Fetch pending verification
        let pendingAddress = await fetchPendingAddress()
        guard let address = pendingAddress else {
            print("No pending verification")
            return
        }
        
        // Step 3: Extract timestamps and schedule
        let lastTimestamp = address.metadata.locations
            .compactMap { ISO8601DateFormatter().date(from: $0.timestamp) }
            .max() ?? Date()
        
        let intervalSeconds: Double
        let sessionDurationSeconds: Double
        
        if isTestingMode {
            // TESTING: 10 second intervals, 2 minute session
            intervalSeconds = 10.0
            sessionDurationSeconds = 120.0  // 2 minutes total
            print("🧪 TESTING MODE: 10 second intervals, 2 minute session")
        } else {
            // PRODUCTION: Use config values
            intervalSeconds = config.geotaggingPollingInterval * 3600
            sessionDurationSeconds = Double(config.geotaggingSessionTimeout) * 86400
            print("🏭 PRODUCTION MODE: Using config intervals")
        }
        
        var current = lastTimestamp.timeIntervalSince1970
        let end = current + sessionDurationSeconds
        let now = Date().timeIntervalSince1970
        
        var timestamps: [TimeInterval] = []
        while current <= end {
            if current > now { timestamps.append(current) }
            current += intervalSeconds
        }
        
        print("🔄 Scheduled \(timestamps.count) timestamps")
        
        // Print all timestamps in readable format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .medium
        
        print("📅 Generated Timestamps:")
        for (index, timestamp) in timestamps.enumerated() {
            let date = Date(timeIntervalSince1970: timestamp)
            let delay = timestamp - Date().timeIntervalSince1970
            let delaySeconds = Int(delay)
            
            print("   \(index + 1). \(dateFormatter.string(from: date)) (in \(delaySeconds)s)")
        }
        
        print("⏰ Current time: \(dateFormatter.string(from: Date()))")
        
        // For testing, process more iterations
        let maxIterations = isTestingMode ? min(timestamps.count, 20) : min(timestamps.count, 10)
        print("🚀 Starting geotag loop with max \(maxIterations) iterations...")
        
        for i in 0..<maxIterations {
            let timestamp = timestamps[i]
            let delay = timestamp - Date().timeIntervalSince1970
            
            if delay > 0 {
                if isTestingMode {
                    let delaySeconds = Int(delay)
                    print("⏳ Waiting \(delaySeconds) seconds until next geotag...")
                } else {
                    let delayMinutes = Int(delay / 60)
                    print("⏳ Waiting \(delayMinutes) minutes until next geotag...")
                }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            print("📍 Processing geotag \(i + 1)/\(maxIterations) at \(dateFormatter.string(from: Date()))")
            await postCurrentLocation()
            
            // Check if we should continue
            if !isGeotaggingActive {
                print("🛑 Geotagging session stopped externally")
                break
            }
        }
        
        print("✅ Finished geotagging session")
        scheduleBackgroundGeotagTask() // Reschedule for next session
        
    }*/
    
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
            apiHelper.fetchCustomerHistory(apiKey: apiKey, token: token)
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
