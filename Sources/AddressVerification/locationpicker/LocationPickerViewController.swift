//
//  LocationPickerViewController.swift
//  AddressVerification
//
//  Created by Richard Uzor on 04/12/2025.
//



// MARK: - 3. LocationPickerViewController.swift
// Sources/AddressVerification/LocationPicker/LocationPickerViewController.swift

#if os(iOS)
import UIKit
import MapKit
import CoreLocation

class LocationPickerViewController: UIViewController {
    
    // UI Components
    private var mapView: MKMapView!
    private var centerPinImageView: UIImageView!
    private var confirmButton: UIButton!
    private var cancelButton: UIButton!
    private var addressLabel: UILabel!
    private var coordinateLabel: UILabel!
    private var currentLocationButton: UIButton!
    private var activityIndicator: UIActivityIndicatorView!
    
    // State
    private var selectedCoordinate: CLLocationCoordinate2D?
    private var selectedAddress: String = "Move map to select location"
    private let geocoder = CLGeocoder()
    private var geocodeTimer: Timer?
    private let locationManager = CLLocationManager()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupLocationManager()
        setupMapView()
        setupCenterPin()
        setupBottomSheet()
        setupCurrentLocationButton()
        
        // Set initial location
        moveToDefaultLocation()
    }
    
    // MARK: - Setup Location Manager
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Setup Map View
    
    private func setupMapView() {
        mapView = MKMapView(frame: view.bounds)
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // iOS 13+ has better map details
        if #available(iOS 13.0, *) {
            mapView.showsBuildings = true
        }
        
        view.addSubview(mapView)
    }
    
    // MARK: - Setup Center Pin
    
    private func setupCenterPin() {
        // Container for pin with shadow
        let pinContainer = UIView()
        pinContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pinContainer)
        
        // Main pin
        centerPinImageView = UIImageView(image: UIImage(systemName: "mappin.circle.fill"))
        centerPinImageView.tintColor = .systemRed
        centerPinImageView.contentMode = .scaleAspectFit
        centerPinImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Shadow layer
        centerPinImageView.layer.shadowColor = UIColor.black.cgColor
        centerPinImageView.layer.shadowOpacity = 0.4
        centerPinImageView.layer.shadowOffset = CGSize(width: 0, height: 3)
        centerPinImageView.layer.shadowRadius = 4
        
        pinContainer.addSubview(centerPinImageView)
        
        NSLayoutConstraint.activate([
            pinContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pinContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -25),
            pinContainer.widthAnchor.constraint(equalToConstant: 60),
            pinContainer.heightAnchor.constraint(equalToConstant: 60),
            
            centerPinImageView.centerXAnchor.constraint(equalTo: pinContainer.centerXAnchor),
            centerPinImageView.centerYAnchor.constraint(equalTo: pinContainer.centerYAnchor),
            centerPinImageView.widthAnchor.constraint(equalToConstant: 50),
            centerPinImageView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Setup Current Location Button
    
    private func setupCurrentLocationButton() {
        currentLocationButton = UIButton(type: .system)
        currentLocationButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        currentLocationButton.backgroundColor = .systemBackground
        currentLocationButton.tintColor = .systemBlue
        currentLocationButton.layer.cornerRadius = 25
        currentLocationButton.layer.shadowColor = UIColor.black.cgColor
        currentLocationButton.layer.shadowOpacity = 0.2
        currentLocationButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        currentLocationButton.layer.shadowRadius = 4
        currentLocationButton.translatesAutoresizingMaskIntoConstraints = false
        currentLocationButton.addTarget(self, action: #selector(moveToCurrentLocation), for: .touchUpInside)
        
        view.addSubview(currentLocationButton)
        
        NSLayoutConstraint.activate([
            currentLocationButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            currentLocationButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -240),
            currentLocationButton.widthAnchor.constraint(equalToConstant: 50),
            currentLocationButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Setup Bottom Sheet
    
    private func setupBottomSheet() {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: -5)
        containerView.layer.shadowRadius = 10
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Drag indicator
        let dragIndicator = UIView()
        dragIndicator.backgroundColor = .systemGray3
        dragIndicator.layer.cornerRadius = 2.5
        dragIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(dragIndicator)
        
        // Info container
        let infoContainer = UIView()
        infoContainer.backgroundColor = .secondarySystemBackground
        infoContainer.layer.cornerRadius = 12
        infoContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(infoContainer)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Selected Location"
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainer.addSubview(titleLabel)
        
        // Address label
        addressLabel = UILabel()
        addressLabel.text = selectedAddress
        addressLabel.font = .systemFont(ofSize: 16)
        addressLabel.numberOfLines = 3
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainer.addSubview(addressLabel)
        
        // Coordinate label
        coordinateLabel = UILabel()
        coordinateLabel.text = "📍 ---, ---"
        coordinateLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        coordinateLabel.textColor = .secondaryLabel
        coordinateLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainer.addSubview(coordinateLabel)
        
        // Activity indicator for geocoding
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        infoContainer.addSubview(activityIndicator)
        
        // Buttons
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelButton.backgroundColor = .systemGray5
        cancelButton.setTitleColor(.label, for: .normal)
        cancelButton.layer.cornerRadius = 12
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        containerView.addSubview(cancelButton)
        
        confirmButton = UIButton(type: .system)
        confirmButton.setTitle("Confirm Location", for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        confirmButton.backgroundColor = .systemBlue
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 12
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        containerView.addSubview(confirmButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 220),
            
            dragIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            dragIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            dragIndicator.widthAnchor.constraint(equalToConstant: 40),
            dragIndicator.heightAnchor.constraint(equalToConstant: 5),
            
            infoContainer.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: 16),
            infoContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            infoContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            titleLabel.topAnchor.constraint(equalTo: infoContainer.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 12),
            
            activityIndicator.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -12),
            
            addressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            addressLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 12),
            addressLabel.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -12),
            
            coordinateLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 8),
            coordinateLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor, constant: 12),
            coordinateLabel.bottomAnchor.constraint(equalTo: infoContainer.bottomAnchor, constant: -12),
            
            cancelButton.topAnchor.constraint(equalTo: infoContainer.bottomAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            cancelButton.heightAnchor.constraint(equalToConstant: 50),
            cancelButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.35),
            
            confirmButton.topAnchor.constraint(equalTo: infoContainer.bottomAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            confirmButton.leadingAnchor.constraint(equalTo: cancelButton.trailingAnchor, constant: 12),
            confirmButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    
    private func moveToDefaultLocation() {
        // Default to Lagos, Nigeria
        let coordinate = CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792)
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapView.setRegion(region, animated: false)
        
        // Request location permission
        locationManager.requestWhenInUseAuthorization()
    }
    
    @objc private func moveToCurrentLocation() {
        if let userLocation = mapView.userLocation.location {
            let region = MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        } else {
            locationManager.requestLocation()
        }
    }
    
    @objc private func cancelTapped() {
        AddressVerificationInternal.shared.pickLocationCallback = nil
        dismiss(animated: true)
    }
    
    @objc private func confirmTapped() {
        guard let coordinate = selectedCoordinate else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        AddressVerificationInternal.shared.sendPickedLocation(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            address: selectedAddress
        )
        dismiss(animated: true)
    }
    
    // MARK: - Geocoding
    
    private func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D) {
        geocodeTimer?.invalidate()
        geocodeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.performReverseGeocode(coordinate)
        }
    }
    
    private func performReverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        activityIndicator.startAnimating()
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            self.activityIndicator.stopAnimating()
            
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
                
                self.selectedAddress = components.isEmpty ? "Unknown location" : components.joined(separator: ", ")
            } else {
                self.selectedAddress = "Unable to resolve address"
            }
            
            self.addressLabel.text = self.selectedAddress
            self.coordinateLabel.text = String(format: "📍 %.6f, %.6f", coordinate.latitude, coordinate.longitude)
        }
    }
}

// MARK: - MKMapViewDelegate

extension LocationPickerViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let center = mapView.centerCoordinate
        selectedCoordinate = center
        reverseGeocodeCoordinate(center)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationPickerViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}
#endif
