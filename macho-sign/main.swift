//
//  main.swift
//  macho-sign
//
//  Created by johankoi on 2021/8/23.
//

import Foundation
import Commander


Group {
//    $0.command("") {
//
//    }
//
//    $0.command("") {
//
//    }

    $0.command("resign",
               Option("filepath",
                      default: "",
                      description: "A mach-o type file path use to resign."),
               Option("provisionPath",
                      default: "",
                      description: "select a mobileProvision file."),
               Option("bundleid",
                      default: "",
                      description: "change bundle identifier in the info.plist of target ipa or other mach-o excuable file."),
               Option("displayName",
                      default: "",
                      description: "change bundle displayName in the info.plist of target ipa or other mach-o excuable file."),
               Option("bundleVersion",
                      default: "",
                      description: "change bundleVersion in the info.plist of target ipa or other mach-o excuable file."),
               Option("bundleShortVersion",
                      default: "",
                      description: "change bundleShortVersion in the info.plist of target ipa or other mach-o excuable file."),
               Option("certificate",
                      default: "",
                      description: "input name of the certificate in login keychan to resign."),
               Option("outputPath",
                      default: "",
                      description: "outputPath after resign."),
               
               description: "resign a mach-o type file"
    ) { filepath, provisionPath, bundleid, displayName, bundleVersion, bundleShortVersion, certificate, outputPath in
        
//        undo: 1.检查证书有效性 2.检查provision 3.检查xcode环境
        let provision = MobileProvisionProcessor.parse(url: URL(fileURLWithPath: provisionPath))
        do {
            let process = try CodeSignProcessor.init()
            try process.sign(filePath: filepath, provision: provision, bundleID: bundleid, displayName: displayName, version: bundleVersion, shortVersion: bundleShortVersion, certificate: certificate, outputPath: outputPath)
        } catch {
            print(error.localizedDescription)
        }
 
    }
}.run()

