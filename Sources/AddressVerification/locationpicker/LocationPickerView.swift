//
//  LocationPickerView.swift
//  AddressVerification
//
//  Created by Richard Uzor on 04/12/2025.
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
    
    let onPicked: (Double, Double, String) -> Void
     
     public init(onPicked: @escaping (Double, Double, String) -> Void) {
         self.onPicked = onPicked
     }
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var selectedAddress: String = "Move map to select location"
    @State private var isGeocoding = false
    
    private let geocoder = CLGeocoder()
//    private let onPicked: (Double, Double, String) -> Void
//    
//    public init(onPicked: @escaping (Double, Double, String) -> Void) {
//        self.onPicked = onPicked
//    }
    
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


            
            // MARK: Center Pin
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 42))
                .foregroundColor(.red)
                .offset(y: -20)
            
            // MARK: Bottom Sheet
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(selectedAddress)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                    
                    if isGeocoding {
                        ProgressView()
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                
                Button(action: confirm) {
                    Text("Confirm Location")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    // MARK: Reverse Geocode
    private func updateAddress(for coord: CLLocationCoordinate2D) {
        isGeocoding = true
        
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
            DispatchQueue.main.async {
                self.isGeocoding = false
                
                if let p = placemarks?.first {
                    let parts = [p.name, p.locality, p.administrativeArea, p.country]
                        .compactMap { $0 }
                    self.selectedAddress = parts.joined(separator: ", ")
                }
            }
        }
    }
    
    // MARK: Confirm Callback
    private func confirm() {
        let c = region.center
        
#if os(iOS)
UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif

        
        onPicked(c.latitude, c.longitude, selectedAddress)
        
        dismiss()
    }
}
