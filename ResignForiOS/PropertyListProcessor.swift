//
//  PlistHelper.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//

import Foundation


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




public struct InfoPlist: Codable {
    private enum CodingKeys: String, CodingKey {
        case bundleName              = "CFBundleName"
        case bundleVersionShort      = "CFBundleShortVersionString"
        case bundleVersion           = "CFBundleVersion"
        case bundleIdentifier        = "CFBundleIdentifier"
        case minOSVersion            = "MinimumOSVersion"
        case xcodeVersion            = "DTXcode"
        case xcodeBuild              = "DTXcodeBuild"
        case sdkName                 = "DTSDKName"
        case buildSDK                = "DTSDKBuild"
        case buildMachineOSBuild     = "BuildMachineOSBuild"
        case buildType               = "method"
        case platformVersion         = "DTPlatformVersion"
        case supportedPlatforms      = "CFBundleSupportedPlatforms"
    }

    public var bundleName:           String
    public var bundleVersionShort:   String
    public var bundleVersion:        String
    public var bundleIdentifier:     String
    public var minOSVersion:         String
    public var xcodeVersion:         String
    public var xcodeBuild:           String
    public var sdkName:              String
    public var buildSDK:             String
    public var buildMachineOSBuild:  String
    // public var buildType:            String
    public var platformVersion:      String
    public var supportedPlatforms:   [String]

    @DecodableDefault.EmptyString  var buildType: String

    public func getBuildType() -> String {
        return buildType
    }
}

public extension InfoPlist {
//    static func parse(from file: File) throws -> InfoPlist {
//        let data = try! Data(contentsOf: file.url)
//        let decoder = PropertyListDecoder()
//        return try! decoder.decode(InfoPlist.self, from: data)
//    }
}





public let RSCFBundleDisplayNameKey             = "CFBundleDisplayName"
public let RSCFBundleIdentifierKey              = "CFBundleIdentifier"
public let RSCFBundleVersionNameKey             = "CFBundleVersion"
public let RSCFBundleShortBundleVersionKey      = "CFBundleShortBundleVersion"
public let RSCFBundleExecutableKey              = "CFBundleExecutable"
public let RSCFBundleResourceSpecificationKey   = "CFBundleResourceSpecification"
public let RSWKCompanionAppBundleIdentifierKey  = "WKCompanionAppBundleIdentifier"
 
class PropertyListProcessor: NSObject {
    
    var plistPath: String
    var dictContent: NSMutableDictionary

    init(with plistPath: String) {
        self.plistPath = plistPath
        dictContent = NSMutableDictionary(contentsOfFile: plistPath) ?? NSMutableDictionary()
    }
    
    func update(with dict: Dictionary<String, String>) {
        dictContent.addEntries(from: dict);
        dictContent.write(toFile: plistPath, atomically: true);
    }
    
    func delete(key: String) {
        dictContent.removeObject(forKey: key);
        dictContent.write(toFile: plistPath, atomically: true);
    }
    
    func getValue(for key: String) -> String? {
        dictContent.object(forKey: key) as? String
    }
    
    func exsistValue(for key: String) -> Bool {
        return getValue(for: key) != nil
    }

}
