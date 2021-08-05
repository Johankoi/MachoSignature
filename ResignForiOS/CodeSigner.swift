//
//  CodeSigner.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//


import Cocoa


class Compress: NSObject {
    
    static let shared = Compress()
    private override init() {}
    
    let unzipPath = "/usr/bin/unzip"
    let zipPath = "/usr/bin/zip"
    
    @discardableResult
    func unzip(_ inputFile: String, outputPath: String) -> Bool {
        let unzipTask = Process().execute(unzipPath, workingDirectory: nil, arguments: ["-q", inputFile, "-d", outputPath])
        if unzipTask.status != 0 {
            setStatus("Error unzip \(inputFile)")
            return false
        }
        return true
    }
    
    @discardableResult
    func zip(_ inputPath: String, outputFile: String) -> Bool {
        let zipTask = Process().execute(zipPath, workingDirectory: inputPath, arguments: ["-qry", outputFile, "."])
        if zipTask.status != 0 {
            setStatus("Error zip path \(inputPath)")
            return false
        }
        return true
    }
}

protocol CodeSignDelegate {
    func codeSignBegin(workingDir: String)
    func codeSignLogRecord(logDes: String)
    func codeSigneEndSuccessed(outPutPath: String, tempDir: String)
    func codeSignError(errDes: String, tempDir: String)
}



//https://github.com/ajpagente/Revamp/blob/master/Sources/Library/Codesign.swift
/**
public struct Signer {
    @discardableResult
    public static func sign(_ file: File, using engine: SigningEngine) throws -> Bool {
        let workspace = try Workspace()
        try workspace.writeFile(file, to: .input, decompress: true)

        let foldersToSign = workspace.inputFolder.findSubfolders(withExtension: [".app", "*.appex", ".framework"])
        for folder in foldersToSign {
            let _ = try engine.sign(folder: folder)
        }

        let resignedFileName    = "rv_\(file.name)"
        try workspace.compressFolder(workspace.inputFolder, to: .output, with: resignedFileName)
        try workspace.copyFileFromOutput(named: resignedFileName, to: file.parent!)
        return true
    }
**/
class CodeSigner: NSObject {
    
    let mktempPath = "/usr/bin/mktemp"
    let chmodPath = "/bin/chmod"
    let codesignPath = "/usr/bin/codesign"
    
    let fileManager = FileManager.default
    
    var delegate: CodeSignDelegate?
    
    func makeTempFolder() -> String? {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.chengcheng.ResignForiOS"
        let tempTask = Process().execute(mktempPath, workingDirectory: nil, arguments: ["-d", "-t", bundleID])
        return tempTask.output
    }
    
    func checkInputAndHandel(_ input: String, _ workingDir: String) -> Bool {
        let payloadDir = workingDir.appendPathComponent("Payload/")
        let dstAppPath = payloadDir.appendPathComponent(input.lastPathComponent)
        
        let inputFormat = input.pathExtension.pathExtentionFormat;
        switch inputFormat {
        case .IPA: do {
            delegate?.codeSignLogRecord(logDes: "Unzip \(input) to \(workingDir)")
            Compress.shared.unzip(input, outputPath: workingDir)
        }
        case .APP: do {
            FileManager.createDirectory(atPath: payloadDir)
            FileManager.copyItem(atPath: input, toPath: dstAppPath)
        }
        case .XCARCHIVE: do {
            FileManager.createDirectory(atPath: payloadDir)
            FileManager.copyItem(atPath: input.appendPathComponent("Products/Applications/"), toPath: dstAppPath)
        }
        case .unknown: return false
        }
        
        return true
    }
       
    
    //MARK: Copy Provisioning Profile
    func checkProfilePath(_ inputProfile: String?, _ oldProfilePath: String) -> String? {
        guard let inputProfile = inputProfile else {
            return oldProfilePath
        }
        FileManager.removeItem(atPath: oldProfilePath)
        if FileManager.copyItem(atPath: inputProfile, toPath: oldProfilePath) == true {
            return inputProfile
        } else {
            return nil
        }
    }

    func sign(inputFile: String, provisioningFile: String?, newBundleID: String, newDisplayName: String, newVersion: String, newShortVersion: String, signingCertificate : String, outputFile: String, openByTerminal: Bool) {
        
        let tempFolder: String = makeTempFolder()!
        
        let workingDirectory = tempFolder.appendPathComponent("out");
        delegate?.codeSignBegin(workingDir: workingDirectory);
        if FileManager.createDirectory(atPath: workingDirectory) == false {
            delegate?.codeSignError(errDes: "Create workingDir error", tempDir: tempFolder)
            return
        }
      
        let entitlementsPlist = tempFolder.appendPathComponent("entitlements.plist")
        let payloadDirectory = workingDirectory.appendPathComponent("Payload/")
        
        
        if checkInputAndHandel(inputFile, workingDirectory) == false {
            delegate?.codeSignError(errDes: "CheckInput: \(inputFile) fail", tempDir: tempFolder)
            return
        }
        
        
        // Loop through app bundles in payload directory
        let files = try? fileManager.contentsOfDirectory(atPath: payloadDirectory)
        var isDirectory: ObjCBool = true
        
        for file in files! {
            fileManager.fileExists(atPath: payloadDirectory.appendPathComponent(file), isDirectory: &isDirectory)
            if !isDirectory.boolValue { continue }
            
            //MARK: Bundle variables setup
            let appFilePath = payloadDirectory.appendPathComponent(file)
            let infoPlistPath = appFilePath.appendPathComponent("Info.plist")
            let provisioningPath = appFilePath.appendPathComponent("embedded.mobileprovision")
            
            let currInfoPlist = PropertyListProcessor(with: infoPlistPath)
            
            
            //MARK: Delete CFBundleResourceSpecification from Info.plist
            currInfoPlist.delete(key: RSCFBundleResourceSpecificationKey)
            
            
            let profilePath = checkProfilePath(provisioningFile, provisioningPath)
            guard let profile = Profile(filePath: profilePath!) else {
                delegate?.codeSignError(errDes: "Creat Profile fail", tempDir: tempFolder)
                continue
            }
            
            var entitleDic = profile.entitlements.fullDictionary
            let xcentPath = appFilePath.appendPathComponent("archived-expanded-entitlements.xcent")
            NSDictionary(contentsOfFile: xcentPath)?.forEach {
                let key = $0 as! String
                let value = $1 as AnyObject
                entitleDic?.updateValue(value, forKey: key)
            }
            (entitleDic! as NSDictionary).write(toFile: entitlementsPlist, atomically: true)
            
            
            //MARK: Make sure that the executable is well... executable.
            if let bundleExecutable = currInfoPlist.getValue(for: RSCFBundleExecutableKey) {
                _ = Process().execute(chmodPath, workingDirectory: nil, arguments: ["755", appFilePath.appendPathComponent(bundleExecutable)])
            }
          
            updatePlist(dict: [:])
            
            //MARK: Codesigning - App
            let signableExts = ["dylib","so","0","vis","pvr","framework","appex","app"]
            recursiveDirectorySearch(appFilePath, extensions: signableExts) { file  in
                codeSign(file, certificate: signingCertificate, entitlements: entitlementsPlist)
            }
            codeSign(appFilePath, certificate: signingCertificate, entitlements: entitlementsPlist)
            
            //MARK: Codesigning - Verification
            let verificationTask = Process().execute(codesignPath, workingDirectory: nil, arguments: ["-v", appFilePath])
            if verificationTask.status != 0 {
                //MARK: alert if certificate  expired
                self.delegate?.codeSignError(errDes: "verifying code sign fail:\(verificationTask.output)", tempDir: tempFolder)
                DispatchQueue.main.async(execute: {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.messageText = "Error verifying code signature!"
                    alert.informativeText = verificationTask.output
                    alert.alertStyle = .critical
                    alert.runModal()
                })
                return
            }
        }
        
        //MARK: Packaging
        //Check if output already exists and delete if so
        FileManager.removeItem(atPath: outputFile)
        
        delegate?.codeSignLogRecord(logDes: "Packaging IPA: \(outputFile)")
        
        Compress.shared.zip(workingDirectory, outputFile: outputFile)
        
        delegate?.codeSigneEndSuccessed(outPutPath: outputFile, tempDir: tempFolder)
        
    }
    
    
    //MARK: Codesigning
    func codeSign(_ file: String, certificate: String, entitlements: String?) {
        delegate?.codeSignLogRecord(logDes: "codeSign:\(file)")
        var arguments = ["-vvv","-fs",certificate,"--no-strict"]
        if fileManager.fileExists(atPath: entitlements!) {
            arguments.append("--entitlements=\(entitlements!)")
        }
        arguments.append(file)
        let codesignTask = Process().execute(codesignPath, workingDirectory: nil, arguments: arguments)
        
        if codesignTask.status != 0 {
            //MARK: alert if certificate expired
            delegate?.codeSignLogRecord(logDes: "Error codesigning \(file) error:\(codesignTask.output)")
        }
    }
    
    

    func updatePlist(dict: Dictionary<String, Any>)  {
        /**
        //MARK: Change Application ID
        if newBundleID != "" {
            if let oldAppID = currInfoPlist.bundleIdentifier {
                //  recursive func
                func changeAppexID(_ appexFile: String) {
                    let appexPlist = PlistHelper(plistPath: appexFile + "/Info.plist")
                    if let appexBundleID = appexPlist.bundleIdentifier {
                        let newAppexID = "\(newBundleID)\(appexBundleID.substring(from: oldAppID.endIndex))"
                        delegate?.codeSignLogRecord(logDes: "Changing \(appexFile) bundleId to \(newAppexID)")
                        appexPlist.bundleIdentifier = newAppexID
                    }
                    if let _ = appexPlist.wkAppBundleIdentifier {
                        appexPlist.wkAppBundleIdentifier = newBundleID
                    }
                    recursiveDirectorySearch(appexFile, extensions: ["app"], found: changeAppexID)
                }
                // Search appex in current app file to changeAppID
                recursiveDirectorySearch(appFilePath, extensions: ["appex"], found: changeAppexID)
            }
            currInfoPlist.bundleIdentifier = newBundleID
        }
        
        //MARK: Change Display Name
        if newDisplayName != "" {
            currInfoPlist.bundleDisplayName = newDisplayName
        }
        
        //MARK: Change Version
        if newVersion != "" {
            currInfoPlist.bundleVersion = newVersion
        }
        
        //MARK: Change Short Version
        if newShortVersion != "" {
            currInfoPlist.shortBundleVersion = newShortVersion
        }
         **/
    }
    func recursiveDirectorySearch(_ path: String, extensions: [String], found: ((_ file: String) -> Void)) {
        if let files = try? fileManager.contentsOfDirectory(atPath: path) {
            var isDirectory: ObjCBool = true
            for file in files {
                let currentFile = path.appendPathComponent(file)
                fileManager.fileExists(atPath: currentFile, isDirectory: &isDirectory)
                if isDirectory.boolValue {
                    recursiveDirectorySearch(currentFile, extensions: extensions, found: found)
                }
                if extensions.contains(file.pathExtension) {
                    found(currentFile)
                }
            }
        }
    }
    
}
