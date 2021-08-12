//
//  PlistHelper.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
// https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/iPhoneOSKeys.html#//apple_ref/doc/uid/TP40009252-SW1

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

//// 修复微信改bundleid后安装失败问题
//let pluginInfoPlist = NSMutableDictionary(contentsOfFile: appexPlist)
//if let dictionaryArray = pluginInfoPlist?["NSExtension"] as? [String:AnyObject],
//    let attributes : NSMutableDictionary = dictionaryArray["NSExtensionAttributes"] as? NSMutableDictionary,
//    let wkAppBundleIdentifier = attributes["WKAppBundleIdentifier"] as? String{
//    let newAppesID = wkAppBundleIdentifier.replacingOccurrences(of:oldAppID, with:newApplicationID);
//    attributes["WKAppBundleIdentifier"] = newAppesID;
//    pluginInfoPlist!.write(toFile: appexPlist, atomically: true);
//}


public struct InfoPlist: Codable {
    
    enum CodingKeys: String, CodingKey {
        case bundleName                   = "CFBundleName"
        case bundleVersionShort           = "CFBundleShortVersionString"
        case bundleVersion                = "CFBundleVersion"
        case bundleIdentifier             = "CFBundleIdentifier"
        case minOSVersion                 = "MinimumOSVersion"
        case xcodeVersion                 = "DTXcode"
        case xcodeBuild                   = "DTXcodeBuild"
        case sdkName                      = "DTSDKName"
        case buildSDK                     = "DTSDKBuild"
        case buildMachineOSBuild          = "BuildMachineOSBuild"
        case platformVersion              = "DTPlatformVersion"
        case supportedPlatforms           = "CFBundleSupportedPlatforms"
        case bundleExecutable             = "CFBundleExecutable"
        case bundleResourceSpecification  = "CFBundleResourceSpecification"
        case companionAppBundleIdentifier = "WKCompanionAppBundleIdentifier"
    }
    
    public var bundleName:                     String
    public var bundleVersionShort:             String
    public var bundleVersion:                  String
    public var bundleIdentifier:               String
    public var minOSVersion:                   String
    public var xcodeVersion:                   String
    public var xcodeBuild:                     String
    public var sdkName:                        String
    public var buildSDK:                       String
    public var buildMachineOSBuild:            String
    public var platformVersion:                String
    public var supportedPlatforms:             [String]
    public var bundleExecutable:               String
    public var bundleResourceSpecification:    String?
    public var companionAppBundleIdentifier:   String?
    
    func write(to path: String) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let data = try encoder.encode(self)
        try! data .write(to: URL(fileURLWithPath: path), options: .atomic)
    }
}


public final class PropertyListProcessor {
    public var content: InfoPlist
    private var plistPath: String
    private var dictContent: NSMutableDictionary
    
    init(with path: String) {
        dictContent = NSMutableDictionary(contentsOfFile: path) ?? NSMutableDictionary()
        plistPath = path
        
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = PropertyListDecoder()
        self.content = try! decoder.decode(InfoPlist.self, from: data)
    }
    
    func modifyBundleName(with new: String) {
        if !new.isEmpty {
            content.bundleName = new
            dictContent.setObject(new, forKey: InfoPlist.CodingKeys.bundleName.rawValue as NSCopying)
            dictContent.write(toFile: plistPath, atomically: true);
        }
    }
    
    func modifyBundleIdentifier(with new: String) {
        if !new.isEmpty {
            content.bundleIdentifier = new
            dictContent.setObject(new, forKey: InfoPlist.CodingKeys.bundleIdentifier.rawValue as NSCopying)
            if let _ = content.companionAppBundleIdentifier {
                dictContent.setObject(new, forKey: InfoPlist.CodingKeys.companionAppBundleIdentifier.rawValue as NSCopying)
            }
            dictContent.write(toFile: plistPath, atomically: true);
        }
    }
    
    func modifyBundleVersionShort(with new: String) {
        if !new.isEmpty {
            content.bundleVersionShort = new
            dictContent.setObject(new, forKey: InfoPlist.CodingKeys.bundleVersionShort.rawValue as NSCopying)
            dictContent.write(toFile: plistPath, atomically: true);
        }
    }
    
    func modifyBundleVersion(with new: String) {
        if !new.isEmpty {
            content.bundleVersion = new
            dictContent.setObject(new, forKey: InfoPlist.CodingKeys.bundleVersion.rawValue as NSCopying)
            try! content.write(to: plistPath)
        }
    }
    func delete(key: String) {
        if !key.isEmpty {
            dictContent.removeObject(forKey: key);
            dictContent.write(toFile: plistPath, atomically: true);
        }
    }
}
