//
//  CachedGeoTag.swift
//  AddressVerification
//
//  Created by Richard Uzor on 28/07/2025.
//


struct CachedGeoTag: Codable {
    let address: String
    let latitude: Double
    let longitude: Double
    let deviceTimestamp: String
}


extension CachedGeoTag {
    static func from(_ request: AddGeoTagRequest) -> CachedGeoTag {
        return CachedGeoTag(
            address: request.address,
            latitude: request.latitude,
            longitude: request.longitude,
            deviceTimestamp: request.deviceTimestamp
        )
    }
}
