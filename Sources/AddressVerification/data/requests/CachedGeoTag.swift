//
//  CachedGeoTag.swift
//  AddressVerification
//
//  Created by Richard Uzor on 28/07/2025.
//

// CachedGeoTag.swift

import Foundation

struct CachedGeoTag: Codable {
    let address: String
    let latitude: Double
    let longitude: Double
    let deviceTimestamp: String
}

extension CachedGeoTag {
    // existing converter from AddGeoTagRequest
    static func from(_ request: AddGeoTagRequest) -> CachedGeoTag {
        return CachedGeoTag(
            address: request.address,
            latitude: request.latitude,
            longitude: request.longitude,
            deviceTimestamp: request.deviceTimestamp
        )
    }

    // new factory: accept Date and convert to ISO string
    static func fromRequest(
        address: String,
        latitude: Double,
        longitude: Double,
        deviceTimestamp: Date
    ) -> CachedGeoTag {
        let ts = ISO8601DateFormatter().string(from: deviceTimestamp)
        return CachedGeoTag(
            address: address,
            latitude: latitude,
            longitude: longitude,
            deviceTimestamp: ts
        )
    }
}
