//
//  AddressVerificationInternal.swift
//  AddressVerification
//
//  Created by Richard Uzor on 04/12/2025.
//



// MARK: - 2. AddressVerificationInternal.swift
// Internal coordinator for callbacks

internal class AddressVerificationInternal {
    static let shared = AddressVerificationInternal()
    private init() {}
    
    var pickLocationCallback: ((Double, Double, String) -> Void)?
    
    func sendPickedLocation(lat: Double, lng: Double, address: String) {
        pickLocationCallback?(lat, lng, address)
        pickLocationCallback = nil
    }
}