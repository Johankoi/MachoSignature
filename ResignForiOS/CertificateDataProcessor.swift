//
//  CertificateDataProcessor.swift
//  ResignForiOS
//
//  Created by skiven on 2021/8/8.
//  Copyright © 2021 cheng. All rights reserved.
//

import Foundation
import Security
/*
https://github.com/slarew/AppleOSS-Security/blob/e1c79a556eb82f18e2c72f2fcab7878d9ecabf5e/OSX/libsecurity_cms/regressions/cms-hashagility-test.c
 **/
public struct SecureCertificate: CustomStringConvertible, Equatable {
    
    public enum CertificateError: Error {
        case failedToCreate
        case failedToObtainSummary
        case failedToObtainValues
    }
    
    public let summary: String
    public let expiryDate: Date?
    
    public init(base64EncodedData: Data) throws {
        
        // Create Certificate
        
        guard let certificate = SecCertificateCreateWithData(nil, base64EncodedData as CFData) else {
            throw CertificateError.failedToCreate
        }
        
        // Error
        
        var error: Unmanaged<CFError>?
        
        func checkError() throws {
            if let error = error {
                throw error.takeUnretainedValue()
            }
        }
        
        // Summary
        
        guard let summary = SecCertificateCopySubjectSummary(certificate) else {
            throw CertificateError.failedToObtainSummary
        }
        
        self.summary = summary as String
        
        // Values (Expiry)
        
        let valuesKeys = [
            kSecOIDInvalidityDate
        ] as CFArray
        
        let values = SecCertificateCopyValues(certificate, valuesKeys, &error)
        try checkError()
        
        guard let dictionary = values as? Dictionary<CFString, Any> else {
            throw CertificateError.failedToObtainValues
        }
        
        let expiryDateDictionary = dictionary[kSecOIDInvalidityDate] as? [String: Any]
        expiryDate = expiryDateDictionary?["value"] as? Date
        
    }
    
    public var description: String {
        return "\(summary), Expires: \(expiryDate?.description ?? "No Expiry Date")"
    }
    
}



public struct Certificate: Encodable, Equatable {
    
    public enum InitError: Error, Equatable {
        case failedToFindValue(key: String)
        case failedToCastValue(expected: String, actual: String)
        case failedToFindLabel(label: String)
    }
    
    public let notValidBefore: Date
    public let notValidAfter:  Date
    
    public let issuerCommonName:  String
    public let issuerCountryName: String
    public let issuerOrgName:     String
    public let issuerOrgUnit:     String
    
    public let serialNumber:      String
    public let fingerprints:      [String:String]
    
    public let commonName:  String?
    public let countryName: String
    public let orgName:     String?
    public let orgUnit:     String
    
    public init(results: [CFString: Any], commonName: String?) throws {
        self.commonName = commonName
        
        notValidBefore = try Certificate.getValue(for: kSecOIDX509V1ValidityNotBefore, from: results)
        notValidAfter = try Certificate.getValue(for: kSecOIDX509V1ValidityNotAfter, from: results)
        
        let issuerName: [[CFString: Any]] = try Certificate.getValue(for: kSecOIDX509V1IssuerName, from: results)
        issuerCommonName = try Certificate.getValue(for: kSecOIDCommonName, fromDict: issuerName)
        issuerCountryName = try Certificate.getValue(for: kSecOIDCountryName, fromDict: issuerName)
        issuerOrgName = try Certificate.getValue(for: kSecOIDOrganizationName, fromDict: issuerName)
        issuerOrgUnit = try Certificate.getValue(for: kSecOIDOrganizationalUnitName, fromDict: issuerName)
        
        serialNumber = try Certificate.getValue(for: kSecOIDX509V1SerialNumber, from: results)
        
        let shaFingerprints: [[CFString: Any]] = try Certificate.getValue(for: "Fingerprints" as CFString, from: results)
        let sha1Fingerprint: Data   = try Certificate.getValue(for: "SHA-1" as CFString, fromDict: shaFingerprints)
        let sha256Fingerprint: Data = try Certificate.getValue(for: "SHA-256" as CFString, fromDict: shaFingerprints)
        
        let sha1   = sha1Fingerprint.map { String(format: "%02x", $0) }.joined()
        let sha256 = sha256Fingerprint.map { String(format: "%02x", $0) }.joined()
        
        self.fingerprints = ["SHA-1":   sha1.uppercased(),
                             "SHA-256": sha256.uppercased()]
        
        let subjectName: [[CFString: Any]] = try Certificate.getValue(for: kSecOIDX509V1SubjectName, from: results)
        countryName = try Certificate.getValue(for: kSecOIDCountryName, fromDict: subjectName)
        orgName = try? Certificate.getValue(for: kSecOIDOrganizationName, fromDict: subjectName)
        orgUnit = try Certificate.getValue(for: kSecOIDOrganizationalUnitName, fromDict: subjectName)
    }
    
    static func getValue<T>(for key: CFString, from values: [CFString: Any]) throws -> T {
        let node = values[key] as? [CFString: Any]
        
        guard let rawValue = node?[kSecPropertyKeyValue] else {
            throw InitError.failedToFindValue(key: key as String)
        }
        
        if T.self is Date.Type {
            if let value = rawValue as? TimeInterval {
                // Force unwrap here is fine as we've validated the type above
                return Date(timeIntervalSinceReferenceDate: value) as! T
            }
        }
        
        guard let value = rawValue as? T else {
            let type = (node?[kSecPropertyKeyType] as? String) ?? String(describing: rawValue)
            throw InitError.failedToCastValue(expected: String(describing: T.self), actual: type)
        }
        
        return value
    }
    
    static func getValue<T>(for key: CFString, fromDict values: [[CFString: Any]]) throws -> T {
        guard let results = values.first(where: { ($0[kSecPropertyKeyLabel] as? String) == (key as String) }) else {
            throw InitError.failedToFindLabel(label: key as String)
        }
        
        guard let rawValue = results[kSecPropertyKeyValue] else {
            throw InitError.failedToFindValue(key: key as String)
        }
        
        guard let value = rawValue as? T else {
            let type = (results[kSecPropertyKeyType] as? String) ?? String(describing: rawValue)
            throw InitError.failedToCastValue(expected: String(describing: T.self), actual: type)
        }
        
        return value
    }
}


public extension Certificate {
    enum ParseError: Error {
        case failedToCreateCertificate
        case failedToCreateTrust
        case failedToExtractValues
    }
    
    static func parse(from data: Data) throws -> Certificate {
        let certificate = try getSecCertificate(data: data)
        
        var error: Unmanaged<CFError>?
        let values = SecCertificateCopyValues(certificate, nil, &error)
        
        if let error = error {
            throw error.takeRetainedValue() as Error
        }
        
        guard let valuesDict = values as? [CFString: Any] else {
            throw ParseError.failedToExtractValues
        }
        
        var commonName: CFString?
        SecCertificateCopyCommonName(certificate, &commonName)
        
        return try Certificate(results: valuesDict, commonName: commonName as String?)
    }
    
    private static func getSecCertificate(data: Data) throws -> SecCertificate {
        guard let certificate = SecCertificateCreateWithData(kCFAllocatorDefault, data as CFData) else {
            throw ParseError.failedToCreateCertificate
        }
        
        return certificate
    }
}

// MARK: - Certificate Encoder/Decoder
public struct BaseCertificate: Codable, Equatable {
    public let data: Data
    public let certificate: Certificate?
    
    // MARK: - Codable
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode(Data.self)
        certificate = try? Certificate.parse(from: data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
    // MARK: - Convenience
    public var base64Encoded: String {
        return data.base64EncodedString()
    }
}
