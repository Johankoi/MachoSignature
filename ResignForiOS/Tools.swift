//
//  Tools.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//

import Foundation
import AppKit

public func updateAppleCer() {
    let script = "do shell script \"/bin/bash \\\"\(Bundle.main.path(forResource: "UpdateAppleCer", ofType: "sh")!)\\\"\" with administrator privileges"
    NSAppleScript(source: script)?.executeAndReturnError(nil)
    return
}


class Log {
    
    static let mainBundle = Bundle.main
    static let bundleID = mainBundle.bundleIdentifier
    static let bundleName = mainBundle.infoDictionary!["CFBundleName"]
    static let bundleVersion = mainBundle.infoDictionary!["CFBundleShortVersionString"]
    static let tempDirectory = NSTemporaryDirectory()
    static var logName = Log.tempDirectory.appendPathComponent("\(Log.bundleID!)-\(Date().timeIntervalSince1970).log")
    
    static func write(_ value:String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let outputStream = OutputStream(toFileAtPath: logName, append: true) {
            outputStream.open()
            let text = "\(formatter.string(from: Date())) \(value)\n"
            let data = text.data(using: String.Encoding.utf8, allowLossyConversion: false)!
            outputStream.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
            outputStream.close()
        }
    }
}


public func setStatus(_ status: String) {
    if !Thread.isMainThread {
        DispatchQueue.main.sync {
            setStatus(status)
        }
    } else {
        Log.write(status)
        print(status)
    }
}

