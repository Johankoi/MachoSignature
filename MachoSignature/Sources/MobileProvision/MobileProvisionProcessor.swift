//
//  MobileProvisionProcessor.swift
//  MachoSignature
//
//  Created by hxq on 2021/8/4.
//  Copyright © 2021 cheng. All rights reserved.
//
/**
 https://github.com/ajpagente/Revamp/tree/master/Sources/Library
 https://github.com/XGPASS/iOSKnowledgeBase/blob/fca7cf46a4807ee9ba18f7c581a462d937c983fd/IPAInspection
 https://github.com/yansaid/ProfilesManager/tree/dcad6a42a6a9d0f44def5f7c806edb98b31961e2/Shared
 */

import Foundation


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
    public var developerCertificates: [CertificateWrapper]
    
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
    
    public var isAppIdentifierWildcard: Bool {
        switch entitlements["application-identifier"] {
        case .string(let value):
            return value.hasSuffix("*")
        default:
            return false
        }
    }

    
    var bundleIdentifier: String {
        switch entitlements["application-identifier"] {
        case .string(let value):
            let cutStart = value.index(value.startIndex, offsetBy: teamIdentifier.count + 1)
            return String(value[cutStart...])
        /** Other Mehods:
         // suffix
         let result1 = value.suffix(value.count - teamIdentifier.count - 1);
         
         let cutPrefix = teamIdentifier + "."
         var range = value.range(of: cutPrefix)!
         
         // suffix from range.upperBound
         let result2 = value.suffix(from: range.upperBound)
         
         // suffix from cutPrefix.endIndex
         let result3 = value.suffix(from: cutPrefix.endIndex)
         **/
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

    public static func == (lhs: ProvisioningProfile, rhs: ProvisioningProfile) -> Bool {
        return true
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
        return "\(name) (Expire: \(expiry))"
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


public final class MobileProvisionProcessor {
    
    private var uuidProvisons = [String: ProvisioningProfile]()
    
    init() {
        guard let libraryDirectoryURL = libraryDirectoryURL() else {
            return
        }
  
        let fileManager = FileManager.default
        let profilesDirectoryURL = libraryDirectoryURL.appendingPathComponent("/MobileDevice/Provisioning Profiles")
        let enumerator = fileManager.enumerator(at: profilesDirectoryURL,
                                                includingPropertiesForKeys: [.nameKey],
                                                options: .skipsHiddenFiles,
                                                errorHandler: nil)!
        
        for case let url as URL in enumerator {
            if let profile = MobileProvisionProcessor.parse(url: url) {
                uuidProvisons[profile.uuid] = profile
            }
        }
    }
    
    
    
    /// Returns all the `ProvisioningProfile` .
    func filterAll() -> [ProvisioningProfile] {
        return uuidProvisons.map{ $1 }
    }
    
    func delete(profile: ProvisioningProfile) {
        if let url = profile.url {
            do {
                try FileManager.default.removeItem(at: url)
                //                profiles.re
                //                profiles.removeAll { $0 == profile }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    
    // UNDO:
    func profilesMatching(_ bundleID: String, acceptWildcardMatches: Bool = false) -> [ProvisioningProfile] {
        
        //        var matches = updateProfiles().filter({ $0.matches(bundleID) })
        //        if !acceptWildcardMatches {
        //            matches = matches.filter({ !$0.isWildcard })
        //        }
        //        return matches
        [ProvisioningProfile]()
    }
    
    /**
     Returns the `ProvisioningProfile` with `name`.
     
     - parameters:
     - name: The name of the profile you provided in the provisioning portal
     - throws:
     */
    func filter(name: String) throws -> ProvisioningProfile? {
        //        return try filter(statusCodes: statusCode...statusCode)
        return nil
    }
    

    //    public static func getUUID(from file: File) throws -> String {
    //           let profile = try parseProfile(from: file)
    //           return profile.UUID
    //       }
    //
    //       public static func getNameUUID(from file: File) throws -> String {
    //           let profile = try parseProfile(from: file)
    //           return "\(profile.UUID)  \(profile.name)"
    //       }
    //
    //       public static func getFileNameUUID(from file: File) throws -> String {
    //           let profile = try parseProfile(from: file)
    //           return "\(profile.UUID)  \(file.name)"
    //       }
    //
    //       public static func getLimitedInfo(from file: File, colorize: Bool = false) throws -> [OutputGroup] {
    //           let groups = try getInfo(from: file, colorize: colorize, translationFile: nil)
    //           return Array(groups.prefix(3))
    //       }
    //
    //       public static func getAllInfo(from file: File, colorize: Bool = false, translateWith translationFile: File? = nil) throws -> [OutputGroup] {
    //           return try getInfo(from: file, colorize: colorize, translationFile: translationFile)
    //       }
    //
    //       private static func getInfo(from file: File, colorize: Bool, translationFile: File?) throws -> [OutputGroup] {
    //           var groups: [OutputGroup] = []
    //           let profile = try parseProfile(from: file)
    //
    //           groups.append(try getProfileInfo(from: profile, colorize: colorize))
    //           groups.append(try getEntitlements(from: profile, colorize: colorize))
    //           groups.append(try getCertificates(from: profile, colorize: colorize))
    //           groups.append(try getProvisionedDevices(from: profile, colorize: colorize, translationFile: translationFile))
    //
    //           let outputGroups = OutputGroups(groups)
    //           return outputGroups.groups
    //       }
    //
    //       public static func getProfileInfo(from file: File, colorize: Bool = false) throws -> [OutputGroup] {
    //           var fileInfo = [String]()
    //           fileInfo.append("File Name: \(file.name)")
    //           let fileInfoGroup = OutputGroup(lines: fileInfo, header: "File Info", separator: ":")
    //
    //           let profile = try parseProfile(from: file)
    //           let profileInfoGroup = try getProfileInfo(from: profile, colorize: colorize)
    //
    //           return [fileInfoGroup, profileInfoGroup]
    //       }
    //
    //       private static func parseProfile(from file: File) throws -> ProvisioningProfile {
    //           let profileURL  = file.url
    //           let data        = try Data(contentsOf: profileURL)
    //           let profile     = try ProvisioningProfile.parse(from: data)
    //           return profile!
    //       }
    //
    //       private static func getProfileInfo(from profile: ProvisioningProfile, colorize: Bool = false) throws -> OutputGroup {
    //           var info: [String] = []
    //           info.append("Profile Name: \(profile.name)")
    //           info.append("Profile UUID: \(profile.UUID)")
    //           info.append("App ID Name: \(profile.appIDName)")
    //           info.append("Team Name: \(profile.teamName)")
    //           info.append("Profile Expiry: \(formatDate(profile.expirationDate, colorizeIfExpired: colorize))")
    //           return OutputGroup(lines: info, header: "Profile Info", separator: ":")
    //       }
    //
    //       private static func getEntitlements(from profile: ProvisioningProfile, colorize: Bool = false) throws -> OutputGroup {
    //           let entitlements = Entitlements(profile.entitlements)
    //           let keys = ["application-identifier", "get-task-allow", "com.apple.developer.nfc.readersession.formats",
    //                       "aps-environment", ]
    //           let filtered = entitlements.filterDisplayableEntitlements(with: keys)
    //           let info = filtered.map { "\($0.key): \($0.value)" }
    //           return OutputGroup(lines: info, header: "Entitlements", separator: ":")
    //       }
    //
    //       private static func getCertificates(from profile: ProvisioningProfile, colorize: Bool = false) throws -> OutputGroup {
    //           var certificateInfo: [String] = []
    //           for (n, certificate) in profile.developerCertificates.enumerated() {
    //               certificateInfo.append("Certificate #: \(n+1)")
    //               certificateInfo.append("Common Name: \(certificate.certificate!.commonName!)")
    //               certificateInfo.append("Team Identifier: \(certificate.certificate!.orgUnit)")
    //               certificateInfo.append("Serial Number: \(certificate.certificate!.serialNumber)")
    //               certificateInfo.append("SHA-1: \(certificate.certificate!.fingerprints["SHA-1"]!)")
    //               certificateInfo.append("Expiry: \(formatDate(certificate.certificate!.notValidAfter, colorizeIfExpired: colorize))")
    //           }
    //           return OutputGroup(lines: certificateInfo, header: "Developer Certificates", separator: ":")
    //       }
    //
    //       private static func getProvisionedDevices(from profile: ProvisioningProfile, colorize: Bool, translationFile: File?) throws -> OutputGroup {
    //           var provisionedDevices: [String] = []
    //           var printDevices: [String] = []
    //           if let file = translationFile {
    //               provisionedDevices = try profile.getTranslatedDevices(using: file)
    //           } else {
    //               if let devices = profile.provisionedDevices { provisionedDevices = devices }
    //           }
    //
    //           let count = provisionedDevices.count
    //           for (n, device) in provisionedDevices.enumerated() {
    //               printDevices.append("Device \(n+1) of \(count): \(device)")
    //           }
    //
    //           return OutputGroup(lines: printDevices, header: "Provisioned Devices", separator: ":")
    //       }
    //
    //       private static func formatDate(_ date: Date, colorizeIfExpired: Bool) -> String {
    //           let dateFormatter = DateFormatter()
    //           dateFormatter.dateFormat = "MMM dd,yyyy"
    //           let dateString = dateFormatter.string(from: date)
    //
    //           let now = Date()
    //           if colorizeIfExpired && date <= now { return "\(dateString, color: .red)" }
    //           else { return dateString }
    //       }
    //
    
    enum ParserError: Error {
        case decoderCreationFailed
        case dataCreationFailed
    }

    public static func parse(url: URL) -> ProvisioningProfile? {
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


// UNDO:
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
