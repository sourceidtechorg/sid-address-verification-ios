# SID Address Verification iOS SDK

Native iOS SDK for real-time address verification with background location tracking.

---

## Before You Begin

Complete the following steps on the **Source ID dashboard** before integrating the SDK:

### 1. Create a Customer

Create a **customer profile** in the Source ID platform. You will receive the **API key**, **customer ID**, and verification credentials.

### 2. Collect User Address Details

Collect the user’s address in your app and submit it to Source ID via your backend using the REST API.

### 3. Invoke the iOS SDK

After submitting the address details, you can begin the SDK-driven background verification process on the device.

---

## Installation (Swift Package Manager)

Add the SDK via Swift Package Manager:

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter the repository URL:

   ```
   https://github.com/sourceidtechorg/sid-ios-address-verification
   ```
3. Select the latest version.
4. Add it to your iOS app target.

---

## Required Permissions (Info.plist)

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>tech.sourceid.addressverification.geotag</string>
</array>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to verify your address.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs always-on location access for verification.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs continuous location access for tracking.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
  <string>processing</string>
  <string>fetch</string>
</array>
```

---

## Enable Xcode Capabilities

Enable the following capabilities for your target:

* **Background Modes**

  * Location updates
  * Background fetch
  * Background processing
* **Background Task Scheduler**
* **Location Updates**

---

## Basic Integration

### 1. Register Background Task

Add this inside `application(_:didFinishLaunchingWithOptions:)` in **AppDelegate.swift**:

```swift
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "tech.sourceid.addressverification.geotag",
    using: nil
) { task in
    guard let processingTask = task as? BGProcessingTask else { return }
    AddressVerificationField.handleBackgroundGeotagTask(processingTask)
}
```

---

## Usage

### Fetch Configuration

```swift
Task {
    do {
        let config = try await AddressVerificationField.fetchConfigFromServer(
            apiKey: "API_KEY",
            customerID: "CUSTOMER_ID",
            token: "VERIFICATION_TOKEN"
        )
        print("Polling Interval: \(config.pollingInterval)")
        print("Session Timeout: \(config.sessionTimeout)")
    } catch {
        print("Error fetching config: \(error)")
    }
}
```

### Start Tracking

```swift
AddressVerificationField.startTrackingWithRemoteConfig(
    apiKey: "API_KEY",
    customerID: "CUSTOMER_ID",
    token: "VERIFICATION_TOKEN",
    onLocationPost: { lat, long in
        print("Posted location: \(lat), \(long)")
    }
)
```

### Stop Tracking

```swift
AddressVerificationField.stopTracking()
```

---

## API Reference

### `fetchConfigFromServer(apiKey, customerID, token)`

Fetches geotagging configuration.

### `startTrackingWithRemoteConfig(apiKey, customerID, token, onLocationPost)`

Starts background geotagging.

### `stopTracking()`

Stops tracking.

---

## Troubleshooting

| Issue                      | Solution                                             |
| -------------------------- | ---------------------------------------------------- |
| Background task not firing | Ensure BGTaskScheduler identifier matches Info.plist |
| No location updates        | Ensure Always & When In Use permissions are granted  |
| Config fetch fails         | Check API key, customer ID, and token                |

---

## Other Platform SDKs

If you prefer other integration:

### Native Android SDK

[https://github.com/sourceidtechorg/sid-android-address-verification](https://github.com/sourceidtechorg/sid-address-verification-android.git)

### React Native

**Repository:** [https://github.com/sourceidtechorg/sid-react-native-address-verification](https://github.com/sourceidtechorg/sid-rn-address-verification.git)

### Flutter Plugin

[https://github.com/sourceidtechorg/sid-flutter-address-verification](https://github.com/sourceidtechorg/sid-flutter-address-verification.git)

---

---

## License

MIT
