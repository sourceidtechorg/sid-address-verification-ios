////
////  LocationPickerScreen.swift
////  AddressVerification
////
////  Created by Richard Uzor on 04/12/2025.
////
//import SwiftUI
//import MapKit
//import CoreLocation
//
//@available(macOS 10.15, *)
//@available(iOS 14.0, *)
//struct LocationPickerScreen: View {
//    @Environment(\.dismiss) private var dismiss
//    
//    // Location manager for current location
//    @StateObject private var locationManager = LocationManager()
//    
//    // Map state
//    @State private var cameraPosition = MapCameraPosition.region(
//        MKCoordinateRegion(
//            center: CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792),
//            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
//        )
//    )
//    
//    @State private var selectedCoordinate: CLLocationCoordinate2D?
//    @State private var resolvedAddress: String = "Move map to select location"
//    @State private var isLoadingAddress = false
//    
//    // Search functionality
//    @State private var searchText = ""
//    @State private var searchResults: [MKMapItem] = []
//    @State private var showSearchResults = false
//    
//    // Debounce timer for reverse geocoding
//    @State private var geocodeTimer: Timer?
//    
//    // UI state
//    @State private var showCurrentLocationButton = true
//    
//    @available(macOS 11.0, *)
//    var body: some View {
//        ZStack {
//            // Map layer
//            mapView
//            
//            // Center crosshair (fixed position)
//            centerPinOverlay
//            
//            // Top controls
//            VStack(spacing: 0) {
//                searchBar
//                if showSearchResults {
//                    searchResultsList
//                }
//                Spacer()
//            }
//            
//            // Floating current location button
//            VStack {
//                Spacer()
//                HStack {
//                    Spacer()
//                    currentLocationButton
//                }
//                .padding(.trailing)
//                .padding(.bottom, 200) // Above bottom sheet
//            }
//            
//            // Bottom sheet
//            VStack {
//                Spacer()
//                locationInfoCard
//            }
//        }
//        .ignoresSafeArea(edges: .bottom)
//        .onAppear(perform: setupInitialLocation)
//    }
//    
//    // MARK: - Map View
//    @ViewBuilder
//    private var mapView: some View {
//        if #available(iOS 17.0, *) {
//            Map(position: $cameraPosition)
//                .mapStyle(.standard(elevation: .realistic))
//                .onMapCameraChange(frequency: .continuous) { context in
//                    selectedCoordinate = context.region.center
//                    debouncedReverseGeocode()
//                }
//        } else {
//            // iOS 14-16: Use traditional Map with binding
//            MapViewiOS14(
//                coordinate: $selectedCoordinate,
//                onRegionChange: { coordinate in
//                    selectedCoordinate = coordinate
//                    debouncedReverseGeocode()
//                }
//            )
//        }
//    }
//    
//    // MARK: - Center Pin Overlay
//    @available(macOS 11.0, *)
//    private var centerPinOverlay: some View {
//        VStack {
//            Spacer()
//            HStack {
//                Spacer()
//                VStack(spacing: 0) {
//                   
//                        Image(systemName: "mappin.circle.fill")
//                            .font(.system(size: 50))
//                            .foregroundColor(.red)
//                            .shadow(color: .black.opacity(0.3), radius: 2)
//                  
//                    
//                    Image(systemName: "arrowtriangle.down.fill")
//                        .font(.system(size: 20))
//                        .foregroundColor(.red)
//                        .offset(y: -12)
//                        .shadow(color: .black.opacity(0.3), radius: 2)
//                }
//                .offset(y: -25) // Shift up so pin point is at center
//                Spacer()
//            }
//            Spacer()
//        }
//        .allowsHitTesting(false)
//    }
//    
//    // MARK: - Current Location Button
//    private var currentLocationButton: some View {
//        Button(action: moveToCurrentLocation) {
//            Image(systemName: locationManager.isLocationAvailable ? "location.fill" : "location.slash.fill")
//                .font(.system(size: 20))
//                .foregroundColor(.white)
//                .frame(width: 50, height: 50)
//                .background(locationManager.isLocationAvailable ? Color.blue : Color.gray)
//                .clipShape(Circle())
//                .shadow(radius: 4)
//        }
//    }
//    
//    // MARK: - Search Bar
//    private var searchBar: some View {
//        HStack {
//            Image(systemName: "magnifyingglass")
//                .foregroundColor(.gray)
//            
//            TextField("Search for a location", text: $searchText)
//                .textFieldStyle(PlainTextFieldStyle())
//                .onChange(of: searchText) { newValue in
//                    searchLocation(query: newValue)
//                }
//            
//            if !searchText.isEmpty {
//                Button(action: {
//                    searchText = ""
//                    searchResults = []
//                    showSearchResults = false
//                }) {
//                    Image(systemName: "xmark.circle.fill")
//                        .foregroundColor(.gray)
//                }
//            }
//        }
//        .padding()
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(radius: 4)
//        .padding()
//    }
//    
//    // MARK: - Search Results List
//    private var searchResultsList: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 0) {
//                ForEach(searchResults, id: \.self) { item in
//                    Button(action: {
//                        selectSearchResult(item)
//                    }) {
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text(item.name ?? "Unknown")
//                                .font(.headline)
//                                .foregroundColor(.primary)
//                            if let address = item.placemark.title {
//                                Text(address)
//                                    .font(.subheadline)
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding()
//                    }
//                    Divider()
//                }
//            }
//        }
//        .frame(maxHeight: 300)
//        .background(Color(.systemBackground))
//        .cornerRadius(12)
//        .shadow(radius: 4)
//        .padding(.horizontal)
//    }
//    
//    // MARK: - Location Info Card
//    private var locationInfoCard: some View {
//        VStack(spacing: 16) {
//            // Drag indicator
//            RoundedRectangle(cornerRadius: 3)
//                .fill(Color.gray.opacity(0.4))
//                .frame(width: 40, height: 5)
//                .padding(.top, 8)
//            
//            // Address display
//            HStack(alignment: .top, spacing: 12) {
//                Image(systemName: "mappin.circle.fill")
//                    .font(.system(size: 24))
//                    .foregroundColor(.blue)
//                
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Selected Location")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    
//                    if isLoadingAddress {
//                        HStack(spacing: 8) {
//                            ProgressView()
//                                .scaleEffect(0.8)
//                            Text("Getting address...")
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
//                        }
//                    } else {
//                        Text(resolvedAddress)
//                            .font(.body)
//                            .foregroundColor(.primary)
//                            .multilineTextAlignment(.leading)
//                            .lineLimit(3)
//                    }
//                    
//                    if let coord = selectedCoordinate {
//                        Text("📍 \(String(format: "%.6f", coord.latitude)), \(String(format: "%.6f", coord.longitude))")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                            .padding(.top, 4)
//                    }
//                }
//                Spacer()
//            }
//            .padding()
//            .background(Color(.secondarySystemBackground))
//            .cornerRadius(12)
//            
//            // Action buttons
//            HStack(spacing: 12) {
//                Button(action: { dismiss() }) {
//                    Text("Cancel")
//                        .fontWeight(.medium)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color(.systemGray5))
//                        .foregroundColor(.primary)
//                        .cornerRadius(12)
//                }
//                
//                Button(action: confirmLocation) {
//                    HStack {
//                        Image(systemName: "checkmark.circle.fill")
//                        Text("Confirm Location")
//                            .fontWeight(.semibold)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(selectedCoordinate != nil ? Color.blue : Color.gray)
//                    .foregroundColor(.white)
//                    .cornerRadius(12)
//                }
//                .disabled(selectedCoordinate == nil || isLoadingAddress)
//            }
//        }
//        .padding()
//        .background(
//            Color(.systemBackground)
//                .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
//        )
//        .cornerRadius(20, corners: [.topLeft, .topRight])
//    }
//    
//    // MARK: - Setup & Actions
//    private func setupInitialLocation() {
//        // Try to use user's current location
//        if let userLocation = locationManager.location?.coordinate {
//            selectedCoordinate = userLocation
//            cameraPosition = .region(
//                MKCoordinateRegion(
//                    center: userLocation,
//                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                )
//            )
//        } else if case .region(let region) = cameraPosition {
//            selectedCoordinate = region.center
//        }
//        
//        reverseGeocodeLocation()
//        locationManager.requestLocation()
//    }
//    
//    private func moveToCurrentLocation() {
//        guard let location = locationManager.location?.coordinate else {
//            locationManager.requestLocation()
//            return
//        }
//        
//        withAnimation {
//            cameraPosition = .region(
//                MKCoordinateRegion(
//                    center: location,
//                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//                )
//            )
//        }
//    }
//    
//    private func debouncedReverseGeocode() {
//        geocodeTimer?.invalidate()
//        geocodeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
//            reverseGeocodeLocation()
//        }
//    }
//    private func searchLocation(query: String) {
//        guard !query.isEmpty else {
//            searchResults = []
//            showSearchResults = false
//            return
//        }
//        
//        let request = MKLocalSearch.Request()
//        request.naturalLanguageQuery = query
//        
//        if case .region(let region) = cameraPosition {
//            request.region = region
//        }
//        
//        let search = MKLocalSearch(request: request)
//        search.start { response, error in
//            if let results = response?.mapItems {
//                searchResults = results
//                showSearchResults = !results.isEmpty
//            }
//        }
//    }
//    
//    private func selectSearchResult(_ item: MKMapItem) {
//        let coordinate = item.placemark.coordinate
//        selectedCoordinate = coordinate
//        resolvedAddress = item.placemark.title ?? "Selected location"
//        
//        // Animate to location
//        cameraPosition = .region(
//            MKCoordinateRegion(
//                center: coordinate,
//                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//            )
//        )
//        
//        searchText = ""
//        showSearchResults = false
//    }
//    
//    private func reverseGeocodeLocation() {
//        guard let coordinate = selectedCoordinate else { return }
//        
//        isLoadingAddress = true
//        
//        let geocoder = CLGeocoder()
//        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
//        
//        geocoder.reverseGeocodeLocation(location) { placemarks, error in
//            DispatchQueue.main.async {
//                isLoadingAddress = false
//                
//                if let place = placemarks?.first {
//                    let components = [
//                        place.name,
//                        place.thoroughfare,
//                        place.subLocality,
//                        place.locality,
//                        place.administrativeArea,
//                        place.postalCode,
//                        place.country
//                    ].compactMap { $0 }
//                    
//                    resolvedAddress = components.isEmpty ? "Unknown location" : components.joined(separator: ", ")
//                } else {
//                    resolvedAddress = "Unable to resolve address"
//                }
//            }
//        }
//    }
//    
//    private func confirmLocation() {
//        guard let coord = selectedCoordinate else { return }
//        
//        // Provide haptic feedback
//        let generator = UIImpactFeedbackGenerator(style: .medium)
//        generator.impactOccurred()
//        
//        AddressVerification.shared.sendPickedLocation(
//            lat: coord.latitude,
//            lng: coord.longitude,
//            address: resolvedAddress
//        )
//        dismiss()
//    }
//}
//
//// MARK: - iOS 14-16 Map Compatibility
//struct MapViewiOS14: UIViewRepresentable {
//    @Binding var coordinate: CLLocationCoordinate2D?
//    let onRegionChange: (CLLocationCoordinate2D) -> Void
//    
//    func makeUIView(context: Context) -> MKMapView {
//        let mapView = MKMapView()
//        mapView.delegate = context.coordinator
//        mapView.showsUserLocation = true
//        mapView.showsCompass = true
//        mapView.showsScale = true
//        return mapView
//    }
//    
//    func updateUIView(_ mapView: MKMapView, context: Context) {
//        // Update map if coordinate changed externally
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, MKMapViewDelegate {
//        var parent: MapViewiOS14
//        
//        init(_ parent: MapViewiOS14) {
//            self.parent = parent
//        }
//        
//        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
//            let center = mapView.centerCoordinate
//            parent.coordinate = center
//            parent.onRegionChange(center)
//        }
//    }
//}
//
//// MARK: - Custom Corner Radius
//extension View {
//    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
//        clipShape(RoundedCorner(radius: radius, corners: corners))
//    }
//}
//
//struct RoundedCorner: Shape {
//    var radius: CGFloat = .infinity
//    var corners: UIRectCorner = .allCorners
//    
//    func path(in rect: CGRect) -> Path {
//        let path = UIBezierPath(
//            roundedRect: rect,
//            byRoundingCorners: corners,
//            cornerRadii: CGSize(width: radius, height: radius)
//        )
//        return Path(path.cgPath)
//    }
//}
//
//// MARK: - Preview
//@available(iOS 14.0, *)
//struct LocationPickerScreen_Previews: PreviewProvider {
//    static var previews: some View {
//        LocationPickerScreen()
//    }
//}
//
//// MARK: - Location Manager
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    private let manager = CLLocationManager()
//    
//    @Published var location: CLLocation?
//    @Published var isLocationAvailable = false
//    
//    override init() {
//        super.init()
//        manager.delegate = self
//        manager.desiredAccuracy = kCLLocationAccuracyBest
//    }
//    
//    func requestLocation() {
//        manager.requestWhenInUseAuthorization()
//        manager.startUpdatingLocation()
//    }
//    
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        location = locations.first
//        isLocationAvailable = true
//        manager.stopUpdatingLocation()
//    }
//    
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("Location error: \(error.localizedDescription)")
//        isLocationAvailable = false
//    }
//    
//    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
//        switch manager.authorizationStatus {
//        case .authorizedWhenInUse, .authorizedAlways:
//            isLocationAvailable = true
//            manager.startUpdatingLocation()
//        case .denied, .restricted:
//            isLocationAvailable = false
//        case .notDetermined:
//            manager.requestWhenInUseAuthorization()
//        @unknown default:
//            break
//        }
//    }
//}
