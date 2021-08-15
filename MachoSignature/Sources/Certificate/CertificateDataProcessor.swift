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
 Github search "SecCertificateCopyValues", filter by codes:
 
 https://github.com/soduto/Soduto/blob/7e3e9a978411c0c572c150493a121339b665b3df/Soduto/Core/CertificateUtils.swift
 https://github.com/abhishekmunie/NIMessages/blob/ddee3d92551b2dcf1e0bc7ff76a192463243eba5/TLSValidation.playground/section-1.swift
 
 https://github.com/KeyTalkInterraIT/macOS_client/blob/b56788018d0b2b0164ab723e9d402f6c0f54bf8c/KeyTalk%20client/Keychain/KeychainCertificate.swift
 
 **/
public struct SecureCertificate: CustomStringConvertible, Equatable {
    
    public enum CertificateError: Error {
        case failedToCreate
        case failedToObtainSummary
        case failedToObtainValues
    }
    
    public let summary: String
    public let expiryDate: Date?
    
    public init(certificate: SecCertificate) throws {
        var error: Unmanaged<CFError>?
        
        func checkError() throws {
            if let error = error {
                throw error.takeUnretainedValue()
            }
        }
        guard let summary = SecCertificateCopySubjectSummary(certificate) else {
            throw CertificateError.failedToObtainSummary
        }
        
        self.summary = summary as String
        
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


public class CertificateDataProcessor {
    
    static func findIdentityForCodeSign() throws -> [SecureCertificate]? {
        var result: CFTypeRef?
        let query: CFDictionary = [
            kSecClass as String: kSecClassIdentity as String,
            kSecMatchLimit as String: kSecMatchLimitAll as String,
            kSecReturnAttributes as String: kSecReturnRef
        ] as CFDictionary
        SecItemCopyMatching(query,&result)
        
        let ids: [SecIdentity]? = result as? [SecIdentity]
        guard let idsArray = ids else {
            return nil
        }
        
        var certificates = [SecureCertificate]()
        for identity in idsArray {
            var cerRef: SecCertificate?
            if SecIdentityCopyCertificate(identity, &cerRef) == noErr {
                guard let cer = cerRef else {
                    return nil
                }
                let certificate = try SecureCertificate(certificate: cer)
                certificates.append(certificate)
            }
        }
        return certificates
    }
    
    static func findCertificates() throws -> [SecureCertificate]? {
        var result: CFTypeRef?
        let query: CFDictionary = [
            kSecClass as String: kSecClassCertificate as String,
            kSecMatchLimit as String: kSecMatchLimitAll as String,
            kSecReturnAttributes as String: kSecReturnRef
        ] as CFDictionary
        SecItemCopyMatching(query,&result)
        
        let cers: [SecCertificate]? = result as? [SecCertificate]
        guard let cersArray = cers else {
            return nil
        }
        var certificates = [SecureCertificate]()
        for cer in cersArray {
            let certificate = try SecureCertificate(certificate: cer)
            certificates.append(certificate)
        }
        return certificates
    }
}




// MARK: - Certificate Encoder/Decoder
public struct CertificateWrapper: Codable, Equatable {
    public let data: Data
    public let certificate: Certificate?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        data = try container.decode(Data.self)
        certificate = try? Certificate.parse(from: data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(data)
    }
    
    public var base64Encoded: String {
        return data.base64EncodedString()
    }
}

public struct Certificate: Encodable, Equatable {
    
    public enum InitError: Error, Equatable {
        case failedToFindValue(key: String)
        case failedToCastValue(expected: String, actual: String)
        case failedToFindLabel(label: String)
    }

    enum ParseError: Error {
        case failedToCreateCertificate
        case failedToCreateTrust
        case failedToExtractValues
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
    
    
    static func parse(from data: Data) throws -> Certificate {
        let certificate = try getSecCertificate(data: data)
        return try self.parse(from: certificate)
    }
    
    static func parse(from certificate: SecCertificate) throws -> Certificate {
        var error: Unmanaged<CFError>? = nil
        let values = SecCertificateCopyValues(certificate, nil, &error)
        if let e = error {
            throw e.takeRetainedValue() as Error
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
    
    
    static func validate(certificate: SecCertificate) -> Bool {
        let oids: [CFString] = [
            kSecOIDX509V1ValidityNotAfter,
            kSecOIDX509V1ValidityNotBefore,
            kSecOIDCommonName
        ]
        let values = SecCertificateCopyValues(certificate, oids as CFArray?, nil) as? [String:[String:AnyObject]]
        return relativeTime(forOID: kSecOIDX509V1ValidityNotAfter, values: values) >= 0.0
            && relativeTime(forOID: kSecOIDX509V1ValidityNotBefore, values: values) <= 0.0
    }
    static func relativeTime(forOID oid: CFString, values: [String:[String:AnyObject]]?) -> Double {
        guard let dateNumber = values?[oid as String]?[kSecPropertyKeyValue as String] as? NSNumber else { return 0.0 }
        return dateNumber.doubleValue - CFAbsoluteTimeGetCurrent();
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

/**
 public static func certificates(in bundle: Bundle = Bundle.main) -> [SecCertificate] {
 var certificates: [SecCertificate] = []
 
 let paths = Set([".cer", ".CER", ".crt", ".CRT", ".der", ".DER"].map { fileExtension in
 bundle.paths(forResourcesOfType: fileExtension, inDirectory: nil)
 }.joined())
 
 for path in paths {
 if
 let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData,
 let certificate = SecCertificateCreateWithData(nil, certificateData)
 {
 certificates.append(certificate)
 }
 }
 
 return certificates
 }
 **/
