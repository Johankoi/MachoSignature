//
//  MobileProvisionProcessor.swift
//  ResignForiOS
//
//  Created by hxq on 2021/8/4.
//  Copyright © 2021 cheng. All rights reserved.
//

import Foundation
import Security


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



public enum PropertyListDictionaryValue: Hashable, Codable, Equatable {
    
    case string(String)
    case bool(Bool)
    case array([PropertyListDictionaryValue])
    case unknown
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([PropertyListDictionaryValue].self) {
            self = .array(array)
        } else {
            self = .unknown
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let string):
            try container.encode(string)
        case .bool(let bool):
            try container.encode(bool)
        case .array(let array):
            try container.encode(array)
        case .unknown:
            break
        }
        
    }
    
}

public struct ProvisioningProfile: Equatable, Codable {
    
    enum CodingKeys: String, CodingKey {
        case appIdName = "AppIDName"
        case applicationIdentifierPrefixs = "ApplicationIdentifierPrefix"
        case creationDate = "CreationDate"
        case platforms = "Platform"
        case developerCertificates = "DeveloperCertificates"
        case entitlements = "Entitlements"
        case expirationDate = "ExpirationDate"
        case name = "Name"
        case provisionedDevices = "ProvisionedDevices"
        case teamIdentifiers = "TeamIdentifier"
        case teamName = "TeamName"
        case timeToLive = "TimeToLive"
        case uuid = "UUID"
        case version = "Version"
    }
    
    public var url: URL?
    
    
    /// The name you gave your App ID in the provisioning portal
    public var appIdName: String
    
    /// The App ID prefix (or Bundle Seed ID) generated when you create a new App ID
    public var applicationIdentifierPrefixs: [String]
    
    /// The date in which this profile was created
    public var creationDate: Date
    
    /// The platforms in which this profile is compatible with
    public var platforms: [String]
    
    /// The array of Base64 encoded developer certificates
    public var developerCertificates: [BaseCertificate]
    
    /// The key value pair of entitlements assosciated with this profile
    public var entitlements: [String: PropertyListDictionaryValue]
    
    /// The date in which this profile will expire
    public var expirationDate: Date
    
    /// The name of the profile you provided in the provisioning portal
    public var name: String
    
    /// An array of device UUIDs that are provisioned on this profile
    public var provisionedDevices: [String]?
    
    /// An array of team identifier of which this profile belongs to
    public var teamIdentifiers: [String]
    
    /// The name of the team in which this profile belongs to
    public var teamName: String
    
    /// The number of days that this profile is valid for. Usually one year (365)
    public var timeToLive: Int
    
    /// The profile's unique identifier, usually used to reference the profile from within Xcode
    public var uuid: String
    
    /// The provisioning profiles version number, currently set to 1.
    public var version: Int
    
    public var isExpired: Bool {
        let now = Date()
        return expirationDate <= now
    }
    
    public var isWildcard: Bool {
        //   return entitlements.applicationIdentifer.hasSuffix("*")
        return true
    }
    
    
    
    public func matches(_ bundleID: String) -> Bool {
        //        var appID = self.entitlements.applicationIdentifer
        //        if let dotRange = appID?.range(of: ".") {
        //            appID = String(describing: appID?[(appID?.startIndex)! ..< dotRange.upperBound])
        //        }
        //        if !isWildcard {
        //            return bundleID == appID
        //        }
        //        return bundleID.hasPrefix(appID!.substring(to: appID!.index(before: appID!.endIndex))) || appID == "*"
        return true
    }
    
    // public var buildType: String
    
    
    var bundleIdentifier: String {
        switch entitlements["application-identifier"] {
        case .string(let value):
            return value
        default:
            return ""
        }
    }
    
    var teamIdentifier: String {
        switch entitlements["com.apple.developer.team-identifier"] {
        case .string(let value):
            return value
        default:
            return ""
        }
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        appIdName = try values.decode(String.self, forKey: .appIdName)
        applicationIdentifierPrefixs = try values.decode([String].self, forKey: .applicationIdentifierPrefixs)
        creationDate = try values.decode(Date.self, forKey: .creationDate)
        platforms = try values.decode([String].self, forKey: .platforms)
        developerCertificates = try values.decode([BaseCertificate].self, forKey: .developerCertificates)
        entitlements = try values.decode([String: PropertyListDictionaryValue].self, forKey: .entitlements)
        expirationDate = try values.decode(Date.self, forKey: .expirationDate)
        name = try values.decode(String.self, forKey: .name)
        provisionedDevices = try values.decode([String].self, forKey: .provisionedDevices)
        teamIdentifiers = try values.decode([String].self, forKey: .teamIdentifiers)
        teamName = try values.decode(String.self, forKey: .teamName)
        timeToLive = try values.decode(Int.self, forKey: .timeToLive)
        uuid = try values.decode(String.self, forKey: .uuid)
        version = try values.decode(Int.self, forKey: .version)
        
    }
    
    public func encode(to encoder: Encoder) throws {
        //           var container = encoder.container(keyedBy: CodingKeys.self)
        //           try container.encode(name, forKey: .name)
        //        .....
    }
    
    
    public static func == (lhs: ProvisioningProfile, rhs: ProvisioningProfile) -> Bool {
        return true
    }
    
    
}

public extension ProvisioningProfile {
    enum ParserError: Error {
        case decoderCreationFailed
        case dataCreationFailed
    }
    
        static func parse(from data: Data) throws -> ProvisioningProfile? {
            guard let decoder = RVCMSDecoder() else {
                throw ParserError.decoderCreationFailed
            }
    
            decoder.updateMessage(with: data as NSData)
            decoder.finalizeMessage()
    
            guard let data = decoder.data else {
                throw ParserError.dataCreationFailed
            }
    
            var profile: ProvisioningProfile?
            do {
                profile = try PropertyListDecoder().decode(ProvisioningProfile.self, from: data)
            } catch {
                debugPrint(error)
                print(error)
                // TODO: log this error
            }
    
            return profile
        }
}

public extension ProvisioningProfile {
        var simpleOutput: String {
            return "\(uuid) \(name)"
        }
    
        var verboseOutput: String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd,yyyy"
    
            let expiry = "\(dateFormatter.string(from: expirationDate))"
            let lines = ["Profile Name: \(name)",
                         "UUID: \(uuid)",
                         "App ID Name: \(appIdName)",
                         "Team Name: \(teamName)",
                         "Expiry: \(expiry)"]
            return "Profile Name: \(name) UUID: \(uuid) Expiry: \(expiry)"
           
        }
        // UNDO:
        private func formatExpired(_ string: String) -> String {
            return string
        }
}

public extension ProvisioningProfile {
        func writeEntitlementsPlist(to filePath: String) throws {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            let data = try encoder.encode(entitlements)
            try data.write(to: URL(fileURLWithPath: filePath))
        }
    
}

public extension ProvisioningProfile {
//        func getTranslatedDevices(using file: File) throws -> [String] {
//            let translator = try DeviceTranslator(file: file)
//            if let devices = provisionedDevices {
//                return try translator.translate(devices)
//            }
//            return []
//        }
}





public final class MobileProvisionProcessor: CustomDebugStringConvertible, Equatable {
    //     添加下面的方法
    //    https://github.com/ajpagente/Revamp/blob/master/Sources/Library/ProfileAnalyzer.swift
    var profiles = [ProvisioningProfile]()
    var loading = false
    
    init() {
        reload()
    }
    
    func reload() {
        guard let libraryDirectoryURL = libraryDirectoryURL() else {
            return
        }
        loading = true
        DispatchQueue.global().async {
            let fileManager = FileManager.default
            let profilesDirectoryURL = libraryDirectoryURL.appendingPathComponent("/MobileDevice/Provisioning Profiles")
            let enumerator = fileManager.enumerator(at: profilesDirectoryURL,
                                                    includingPropertiesForKeys: [.nameKey],
                                                    options: .skipsHiddenFiles,
                                                    errorHandler: nil)!
            
            var profiles = [ProvisioningProfile]()
            for case let url as URL in enumerator {
                if let profile = self.parse(url: url) {
                    profiles.append(profile)
                }
            }
            
            DispatchQueue.main.async {
                self.loading = false
                self.profiles = profiles
            }
        }
    }
    
    
    func delete(profile: ProvisioningProfile) {
        if let url = profile.url {
            do {
                try FileManager.default.removeItem(at: url)
                profiles.removeAll { $0 == profile }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    func profilesMatching(_ bundleID: String, acceptWildcardMatches: Bool = false) -> [ProvisioningProfile] {
       
//        var matches = updateProfiles().filter({ $0.matches(bundleID) })
//        if !acceptWildcardMatches {
//            matches = matches.filter({ !$0.isWildcard })
//        }
//        return matches
        [ProvisioningProfile]()
    }
    
    //有效的未过期mobileProvision[] collection成 -> 名字数组
    //从mobileProvision名字获取mobileProvision 进而 得到 包含的证书信息类
    
    func installedMobileProvisions() -> [String] { return [""] }
    
    func mapProvisionToStringArray() -> [String] { return [""] }
    
    func developerCertificates(in: [String:String]) -> [String] { return [""] }
    
    
    public var debugDescription: String = ""
    
    public static func == (lhs: MobileProvisionProcessor, rhs: MobileProvisionProcessor) -> Bool {
        return true
    }
    
    private func parse(url: URL) -> ProvisioningProfile? {
        var profile: ProvisioningProfile? = nil
        do {
            let data = try Data(contentsOf: url)
            var decoder: CMSDecoder?
            CMSDecoderCreate(&decoder)
            if let decoder = decoder {
                guard CMSDecoderUpdateMessage(decoder, [UInt8](data), data.count) != errSecUnknownFormat else { return nil }
                guard CMSDecoderFinalizeMessage(decoder) != errSecUnknownFormat else { return nil }
                var newData: CFData?
                CMSDecoderCopyContent(decoder, &newData)
                if let data = newData as Data? {
                    profile = try PropertyListDecoder().decode(ProvisioningProfile.self, from: data)
                    profile?.url = url
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return profile
    }
    
    private func libraryDirectoryURL() -> URL? {
        let pw = getpwuid(getuid())
        guard let pw_dir = pw?.pointee.pw_dir,
              let realHomeDir = String(utf8String: pw_dir) else { return nil }
        return URL(fileURLWithPath: realHomeDir).appendingPathComponent("Library")
    }
    
}


// undo ：



// 1.如果描述文件指定了一些设备，说明这个描述文件用来限制一些设备安装或者调试：
// getTaskAllow是yes，就表明这个是可调试的的描述文件，no代表是Ad Hoc类型证书
// 2.如果描述文件未指定任何设备，说明这个包描述文件用来发布appstore，或者是Enterprise类型
// ProvisionsAllDevices是yes，代表是Enterprise，no就是发布证书

//    // 查看描述文件是否指定了调试设备
//    - (BOOL)hasDevices
//    {
//        if ([_provisionDict[@"ProvisionedDevices"] isKindOfClass:[NSArray class]]) {
//            return YES;
//        } else {
//            return NO;
//        }
//    }
//
//    // ProvisionsAllDevices yes代表 app是Enterprise 类型的
//    - (BOOL)isEnterprise
//    {
//        return [_provisionDict[@"ProvisionsAllDevices"] boolValue];
//    }
//    - (NSString *)type
//    {
//        if (self.hasDevices) {
//            if (self.getTaskAllow) {
//                return @"Development";
//            } else {
//                return @"Distribution (Ad Hoc)";
//            }
//        } else {
//            if (self.isEnterprise) {
//                return @"Enterprise";
//            } else {
//                return @"Distribution (App Store)";
//            }
//        }
//    }
