//
//  PlistHelper.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//

import Foundation

open class PlistHelper: NSObject {
    
    let defaultsPath = "/usr/bin/defaults"
    var plistPath: String?
    
    public convenience init(plistPath: String?) {
        self.init()
        self.plistPath = plistPath
    }
    
    var bundleDisplayName: String? {
        set {
            setValue(newValue!, for: "CFBundleDisplayName")
        }
        get {
            return getValue(for: "CFBundleDisplayName")
        }
    }
    
    var bundleIdentifier: String? {
        set {
            setValue(newValue!, for: "CFBundleIdentifier")
        }
        get {
            return getValue(for: "CFBundleIdentifier")
        }
    }
    
    var wkAppBundleIdentifier: String? {
        set {
            setValue(newValue!, for: "WKCompanionAppBundleIdentifier")
        }
        get {
            return getValue(for: "WKCompanionAppBundleIdentifier")
        }
    }
    var bundleVersion: String? {
        set {
            setValue(newValue!, for: "CFBundleVersion")
        }
        get {
            return getValue(for: "CFBundleVersion")
        }
    }
    var shortBundleVersion: String? {
        set {
            setValue(newValue!, for: "CFBundleShortBundleVersion")
        }
        get {
            return getValue(for: "CFBundleShortBundleVersion")
        }
    }
    
    var bundleExecutable: String? {
        set {
            setValue(newValue!, for: "CFBundleExecutable")
        }
        get {
            return getValue(for: "CFBundleExecutable")
        }
    }
    
    
    func delete(key: String) {
        _ = Process().execute(defaultsPath, workingDirectory: nil, arguments: ["delete", plistPath!, key])
    }
    func getValue(for key: String) -> String? {
        return Process().execute(defaultsPath, workingDirectory: nil, arguments: ["read", plistPath!, key]).output
    }
    
    func exsistValue(for key: String) -> Bool {
        return getValue(for: key) != nil
    }
    
    func setValue(_ value: String, for key: String) {
        setStatus("\(plistPath!) Changing \(key) to \(value))")
        let task = Process().execute(defaultsPath, workingDirectory: nil, arguments: ["write", plistPath!, key, value])
        if task.status != 0 {
            setStatus("\(plistPath!) Changing \(key) to \(value)) Error!!!")
        }
    }
}
