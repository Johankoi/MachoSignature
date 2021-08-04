//
//  PlistHelper.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//

import Foundation

public let RSCFBundleDisplayNameKey             = "CFBundleDisplayName"
public let RSCFBundleIdentifierKey              = "CFBundleIdentifier"
public let RSCFBundleVersionNameKey             = "CFBundleVersion"
public let RSCFBundleShortBundleVersionKey      = "CFBundleShortBundleVersion"
public let RSCFBundleExecutableKey              = "CFBundleExecutable"
public let RSCFBundleResourceSpecificationKey   = "CFBundleResourceSpecification"
public let RSWKCompanionAppBundleIdentifierKey  = "WKCompanionAppBundleIdentifier"
 
class PropertyListProcessor: NSObject {
    
    let defaultsPath = "/usr/bin/defaults"
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
