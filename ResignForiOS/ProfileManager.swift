//
//  ProfileManager.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//
import Cocoa
import Security


open class ProfileManager {
    
    fileprivate var directoryPath: String?
    
    init(directoryPath: String? = nil) {
        self.directoryPath = directoryPath
    }
    
    open var profilesPath: String {
        if let path = directoryPath {
            return path
        } else {
            let libraryDir = FileManager().urls(for: .libraryDirectory, in: .userDomainMask).first!
            directoryPath = libraryDir.appendingPathComponent("MobileDevice/Provisioning Profiles").path
            return self.profilesPath
        }
    }
    
    // MARK: expired Profiles
    open var expiredProfiles: [Profile] = []
    
    open func updateProfiles() -> [Profile] {
        var validProfiles: [Profile] = []
        if let contentFiles = try? FileManager.default.contentsOfDirectory(atPath: profilesPath) {
            let mobileprovisions = contentFiles.filter({URL(fileURLWithPath: $0).pathExtension == "mobileprovision"})
            for profile in mobileprovisions {
                if let profile = Profile(filePath: profilesPath + "/" + profile) {
                    if profile.isExpired == false {
                        validProfiles.append(profile)
                    } else {
                        expiredProfiles.append(profile)
                    }
                }
            }
        }
        return validProfiles
    }
    
    
    open func profilesMatching(_ bundleID: String, acceptWildcardMatches: Bool = false) -> [Profile] {
       
        var matches = updateProfiles().filter({ $0.matches(bundleID) })
        if !acceptWildcardMatches {
            matches = matches.filter({ !$0.isWildcard })
        }
        return matches
    }
    
}


//==========================================================================
// MARK: Profile Constants Keys
//==========================================================================

fileprivate let creationDateKey = "CreationDate"
fileprivate let expirationDateKey = "ExpirationDate"

fileprivate let appIDNameKey = "AppIDName"
fileprivate let applicationIdentifierPrefixKey = "ApplicationIdentifierPrefix"
fileprivate let developerCertificatesKey = "DeveloperCertificates"
fileprivate let entitlementsKey = "Entitlements"
fileprivate let nameKey = "Name"
fileprivate let provisionsAllDevicesKey = "ProvisionsAllDevices"
fileprivate let provisionedDevicesKey = "ProvisionedDevices"
fileprivate let teamIdentifierKey = "TeamIdentifier"
fileprivate let teamNameKey = "TeamName"
fileprivate let timeToLiveKey = "TimeToLive"
fileprivate let UUIDKey = "UUID"
fileprivate let versionKey = "Version"


//==========================================================================
// MARK: Entitlements Constants Keys
//==========================================================================

// General
fileprivate let applicationIdentiferKey = "application-identifier"
fileprivate let betaReportsActiveKey = "beta-reports-active"
fileprivate let getTaskAllowKey = "get-task-allow"
fileprivate let keychainAccessGroupsKey = "keychain-access-groups"
fileprivate let teamIdKey = "com.apple.developer.team-identifier"

// Push
fileprivate let apsEnvironmentKey = "aps-environment"

// iCloud
fileprivate let ubiquityStoreIdentifierKey = "com.apple.developer.ubiquity-kvstore-identifier"




//==========================================================================
// MARK: Provisioning Profile
//==========================================================================

open class Profile: NSObject {

    open var filePath: String?

    // MARK: Profile Properties
    open let applicationIdentifierPrefix: [String]
    open let appIDName: String?
    open var bundleID: String = ""
    
    open var developerCertificates: [String] = []
    open let entitlements: Entitlements!
    open let name: String
    open let provisionsAllDevices: Bool
    open let provisionedDevices: [String]
    open let teamIdentifiers: [String]
    open let teamName: String?
    open let timeToLive: Int
    open let uuid: String!
    open let version: Int
    
    open let creationDate: Date!
    open let expirationDate: Date!
    
    open var isExpired: Bool {
        return self.expirationDate.timeIntervalSinceNow < 0
    }
    
    open var isWildcard: Bool {
        return entitlements.applicationIdentifer.hasSuffix("*")
    }
    
    open var type: String = ""
    
    open func matches(_ bundleID: String) -> Bool {
        var appID = self.entitlements.applicationIdentifer
        if let dotRange = appID?.range(of: ".") {
            appID = String(describing: appID?[(appID?.startIndex)! ..< dotRange.upperBound])
        }
        if !isWildcard {
            return bundleID == appID
        }
        return bundleID.hasPrefix(appID!.substring(to: appID!.index(before: appID!.endIndex))) || appID == "*"
    }
    
    
    // MARK: Initialize with a decoded Profile info Dict
    public init?(dictionary: [String: AnyObject]?) {
        self.creationDate = dictionary?[creationDateKey] as? Date
        self.expirationDate = dictionary?[expirationDateKey] as? Date
        self.appIDName = dictionary?[appIDNameKey] as? String
        self.applicationIdentifierPrefix = dictionary?[applicationIdentifierPrefixKey] as? [String] ?? []
        self.entitlements = Entitlements(dictionary: dictionary?[entitlementsKey] as? [String: AnyObject])
        
        let devCerDatas = dictionary?[developerCertificatesKey] as? [Data] ?? []
        for cer in devCerDatas {
            let certificateRef = SecCertificateCreateWithData(nil, cer as CFData)
            let summary = SecCertificateCopySubjectSummary(certificateRef!)
            self.developerCertificates.append(summary! as String)
        }
        
        let appID = entitlements.applicationIdentifer
        let index = appID?.index((appID?.startIndex)!, offsetBy: (applicationIdentifierPrefix.first?.count)! + 1)
        self.bundleID = (appID?.substring(from: index!))!.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
        
        self.name = (dictionary?[nameKey] as? String)!
        self.provisionsAllDevices = dictionary?[provisionsAllDevicesKey] as? Bool ?? false
        self.provisionedDevices = dictionary?[provisionedDevicesKey] as? [String] ?? []
        self.teamIdentifiers = dictionary?[teamIdentifierKey] as? [String] ?? []
        self.teamName = dictionary?[teamNameKey] as? String
        self.timeToLive = dictionary?[timeToLiveKey] as? Int ?? 0
        self.uuid = dictionary?[UUIDKey] as? String
        self.version = dictionary?[versionKey] as? Int ?? 0
    }
    
    public convenience init?(filePath path: String) {
        self.init(dictionary: Profile.decodeProfile(path: path))
        self.filePath = path
    }
    
    public convenience init?(fileURL url: URL) {
        self.init(filePath: url.path)
    }
    
    
    // MARK: Decode Profile with a path
    fileprivate class func decodeProfile(path: String) -> [String: AnyObject]? {
        if let profileData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            var optionalDecoder: CMSDecoder?
            var optionalDataRef: CFData?
            
            CMSDecoderCreate(&optionalDecoder)
            if let decoderRef = optionalDecoder {
                CMSDecoderUpdateMessage(decoderRef, (profileData as NSData).bytes, Int(profileData.count))
                CMSDecoderFinalizeMessage(decoderRef)
                CMSDecoderCopyContent(decoderRef, &optionalDataRef)
                
                let decodedProfileData = optionalDataRef! as Data
                let plistDict = try! PropertyListSerialization.propertyList(from: decodedProfileData, options: .mutableContainersAndLeaves, format: nil)
                return plistDict as? [String: AnyObject]
            }
        }
        return nil
    }
}

//==========================================================================
// MARK: Entitlements
//==========================================================================

open class Entitlements {
    
    public let fullDictionary: [String: AnyObject]!
    
    // General
    open let applicationIdentifer: String!
    open let betaReportsActive: Bool
    open let getTaskAllow: Bool
    open let keychainAccessGroups: [String]
    open let teamIdentifier: String?
    
    // Push
    open let apsEnvironment: String
    
    // iCloud
    open let ubiquityStoreIdentifier: String?
    
    init?(dictionary: [String: AnyObject]?) {
        self.fullDictionary = dictionary
        
        // General
        self.applicationIdentifer = dictionary?[applicationIdentiferKey] as? String
        self.betaReportsActive = dictionary?[betaReportsActiveKey] as? Bool ?? false
        self.getTaskAllow = dictionary?[getTaskAllowKey] as? Bool ?? false
        self.keychainAccessGroups = dictionary?[keychainAccessGroupsKey] as? [String] ?? []
        self.teamIdentifier = dictionary?[teamIdKey] as? String
        
        // Push
        self.apsEnvironment = dictionary?[apsEnvironmentKey] as? String ?? ""
        
        // iCloud
        self.ubiquityStoreIdentifier = dictionary?[ubiquityStoreIdentifierKey] as? String
        
        if (self.fullDictionary == nil || self.applicationIdentifer == nil) {
            return nil
        }
    }
}
