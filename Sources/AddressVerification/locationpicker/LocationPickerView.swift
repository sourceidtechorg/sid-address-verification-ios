//
//  LocationPickerView.swift
//  AddressVerification
//
//  SwiftUI version with ResolvedAddress and current location
//

import SwiftUI
import MapKit
import CoreLocation

#if os(iOS)
import UIKit
#endif

@available(iOS 15.0, *)
@available(macOS 12.0, *)
public struct LocationPickerView: View {
    
    let onPicked: (ResolvedAddress) -> Void
    
    public init(onPicked: @escaping (ResolvedAddress) -> Void) {
        self.onPicked = onPicked
    }
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationViewModel = LocationViewModel()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var currentResolvedAddress: ResolvedAddress?
    @State private var isGeocoding = false
    @State private var hasSetInitialLocation = false
    
    private let geocoder = CLGeocoder()
    
    public var body: some View {
        ZStack {
            // MARK: Map
            Map(coordinateRegion: $region, showsUserLocation: true)
                .ignoresSafeArea()
                .onChange(of: region.center.latitude) { _ in
                    updateAddress(for: region.center)
                }
                .onChange(of: region.center.longitude) { _ in
                    updateAddress(for: region.center)
                }
                .onAppear {
                    locationViewModel.requestLocation { coordinate in
                        if !hasSetInitialLocation {
                            region.center = coordinate
                            hasSetInitialLocation = true
                        }
                    }
                }
            
            // MARK: Center Pin
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 42))
                .foregroundColor(.red)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .offset(y: -20)
            
            // MARK: Current Location Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: moveToCurrentLocation) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 50)
#if os(iOS)
                         .background(Color(uiColor: .systemBackground))
                         #else
                         .background(Color(nsColor: .windowBackgroundColor))
                         #endif
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 16)
                }
                Spacer()
            }
            .padding(.bottom, 240)
            
            // MARK: Bottom Sheet
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Selected Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if isGeocoding {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    Text(currentResolvedAddress?.fullAddress ?? "Move map to select location")
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                    
                    if let address = currentResolvedAddress {
                        Text(String(format: "📍 %.6f, %.6f", address.latitude, address.longitude))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                        
#if os(iOS)
                        .background(Color(uiColor: .systemGray5))
                        #else
                        .background(Color(nsColor: .controlBackgroundColor))
                        #endif
                            .cornerRadius(12)
                    }
                    
                    Button(action: confirm) {
                        Text("Confirm Location")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    // MARK: - Helper Methods
    
    private func moveToCurrentLocation() {
        locationViewModel.requestLocation { coordinate in
            withAnimation {
                region.center = coordinate
            }
        }
    }
    
    private func updateAddress(for coord: CLLocationCoordinate2D) {
        isGeocoding = true
        
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let place = placemarks?.first {
                    let components = [
                        place.name,
                        place.thoroughfare,
                        place.subLocality,
                        place.locality,
                        place.administrativeArea,
                        place.postalCode,
                        place.country
                    ].compactMap { $0 }
                    
                    let fullAddress = components.isEmpty ? "Unknown location" : components.joined(separator: ", ")
                    
                    self.currentResolvedAddress = ResolvedAddress(
                        latitude: coord.latitude,
                        longitude: coord.longitude,
                        fullAddress: fullAddress,
                        country: place.country,
                        state: place.administrativeArea,
                        city: place.locality ?? place.subAdministrativeArea,
                        postalCode: place.postalCode,
                        street: place.thoroughfare
                    )
                } else {
                    self.currentResolvedAddress = ResolvedAddress(
                        latitude: coord.latitude,
                        longitude: coord.longitude,
                        fullAddress: "Unable to resolve address"
                    )
                }
            }
        }
    }
    
    private func confirm() {
        guard let address = currentResolvedAddress else { return }
        
#if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
        
        onPicked(address)
        dismiss()
    }
}

// MARK: - Location View Model

@available(iOS 14.0, *)
@available(macOS 11.0, *)
class LocationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationCallback: ((CLLocationCoordinate2D) -> Void)?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation(completion: @escaping (CLLocationCoordinate2D) -> Void) {
        locationCallback = completion
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            // Default to Lagos
            completion(CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792))
        @unknown default:
            completion(CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            locationCallback?(location.coordinate)
            locationCallback = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationCallback?(CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792))
        locationCallback = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
          #if os(iOS)
          if manager.authorizationStatus == .authorizedWhenInUse ||
             manager.authorizationStatus == .authorizedAlways {
              manager.requestLocation()
          }
          #elseif os(macOS)
          if manager.authorizationStatus == .authorizedAlways {
              manager.requestLocation()
          }
          #endif
      }
}
