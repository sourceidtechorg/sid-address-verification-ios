//
//  ResolvedAddress.swift
//  AddressVerification
//
//  Created by Richard Uzor on 15/12/2025.
//


//
//  ResolvedAddress.swift
//  AddressVerification
//
//  Enhanced address structure matching Android implementation
//

import Foundation

/// Comprehensive address structure with all location components
public struct ResolvedAddress {
    public let latitude: Double
    public let longitude: Double
    public let fullAddress: String
    public let country: String?
    public let state: String?
    public let city: String?
    public let postalCode: String?
    public let street: String?
    
    public init(
        latitude: Double,
        longitude: Double,
        fullAddress: String,
        country: String? = nil,
        state: String? = nil,
        city: String? = nil,
        postalCode: String? = nil,
        street: String? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.fullAddress = fullAddress
        self.country = country
        self.state = state
        self.city = city
        self.postalCode = postalCode
        self.street = street
    }
}