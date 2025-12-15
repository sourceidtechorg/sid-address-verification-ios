//
//  AddressVerificationInternal.swift
//  AddressVerification
//
//  Updated to use ResolvedAddress structure
//

import Foundation

internal class AddressVerificationInternal {
    static let shared = AddressVerificationInternal()
    private init() {}
    
    var pickLocationCallback: ((ResolvedAddress) -> Void)?
    
    func sendPickedLocation(_ address: ResolvedAddress) {
        pickLocationCallback?(address)
        pickLocationCallback = nil
    }
}
