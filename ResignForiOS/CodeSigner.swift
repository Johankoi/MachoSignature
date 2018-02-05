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




class CodeSigner: NSObject {
    
    let mktempPath = "/usr/bin/mktemp"
    let chmodPath = "/bin/chmod"
    let codesignPath = "/usr/bin/codesign"

    let fileManager = FileManager.default
    
    func makeTempFolder() -> String? {
        let bundleID = Bundle.main.bundleIdentifier
        let tempTask = Process().execute(mktempPath, workingDirectory: nil, arguments: ["-d", "-t", bundleID!])
        return tempTask.output
    }
    
    func checkInputAndHandel(_ input: String, _ output: String) -> Bool {
        let payloadDir = output.appendPathComponent("Payload/")
        let inputFileExt = input.pathExtension.lowercased()
        if inputFileExt == "ipa" {
            Compress.shared.unzip(input, outputPath: output)
        } else if inputFileExt == "app" {
            do {
                try fileManager.createDirectory(atPath: payloadDir, withIntermediateDirectories: true, attributes: nil)
                try fileManager.copyItem(atPath: input, toPath: payloadDir.appendPathComponent(input.lastPathComponent))
                setStatus("Copying app to payload directory")
            } catch {
                setStatus("Error copying app to payload directory")
                return false
            }
        } else {
            setStatus("input file not ipa")
            return false
        }

        // Check ipa Payload directory to judge if the Task above successed
        if !fileManager.fileExists(atPath: output.appendPathComponent("Payload/")) {
            setStatus("Payload directory doesn't exist")
            return false
        }
        return true
    }
    
    
    func cleanup(_ tempFolder: String) {
        do {
            setStatus("Deleting: \(tempFolder)")
            try fileManager.removeItem(atPath: tempFolder)
        } catch let error as NSError {
            setStatus("delete tempfolder error \(error.localizedDescription)")
        }
    }
    
    //MARK: Copy Provisioning Profile
    func copyProvisionProfile(_ inputProfile: String?, _ oldProfilePath: String, _ tempDir: String) -> Bool {
        var profilePath: String? = nil
        if let inputProfile = inputProfile {
            if fileManager.fileExists(atPath: oldProfilePath) {
                setStatus("overWrite new provisioning profile to app bundle")
                do {
                    try fileManager.removeItem(atPath: oldProfilePath)
                    try fileManager.copyItem(atPath: inputProfile, toPath: oldProfilePath)
                    profilePath = inputProfile
                } catch let error as NSError {
                    setStatus("Error copying provisioning profile \(error.localizedDescription)")
                    return false
                }
            }
        } else {
            profilePath = oldProfilePath
        }
        
        // write entitlements to  entitlements.plist in the tempDir for save before codesign
        if let profilePath = profilePath {
            let profile = Profile(filePath: profilePath)!
            let result = profile.writeEntitlements(toFile: tempDir + "/entitlements.plist")
            setStatus("Write entitlements to plist \(result ? "ok" : "error")")
            return result
        } else {
            return false
        }
    }
    
    
    func sign(inputFile: String, provisioningFile: String?, newBundleID: String, newDisplayName: String, newVersion: String, newShortVersion: String, signingCertificate : String, outputFile: String, openByTerminal: Bool) {

        //MARK: Create working temp folder
        var tempFolder: String = makeTempFolder()!
        
        let workingDirectory = tempFolder.appendPathComponent("out")
        let entitlementsPlist = tempFolder.appendPathComponent("entitlements.plist")
        let payloadDirectory = workingDirectory.appendPathComponent("Payload/")
        
        setStatus("Working directory: \(workingDirectory)")
        setStatus("Payload folder: \(payloadDirectory)")
        
        //MARK: Codesign Test
        
        //MARK: Create workingDirectory Temp Directory
        do {
            try fileManager.createDirectory(atPath: workingDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            setStatus("Error creating directory \(error.localizedDescription)")
            cleanup(tempFolder)
            return
        }
        
        
        if checkInputAndHandel(inputFile, workingDirectory) == false {
            setStatus("Write entitlements fail")
            cleanup(tempFolder)
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
            
            let currInfoPlist = PlistHelper(plistPath: infoPlistPath)
            
            //MARK: Delete CFBundleResourceSpecification from Info.plist
            currInfoPlist.delete(key: "CFBundleResourceSpecification")

            
            //MARK: copy provisionProfile
            if copyProvisionProfile(provisioningFile, provisioningPath, tempFolder) == false {
                cleanup(tempFolder);
            }
            
            //MARK: Make sure that the executable is well... executable.
            if let bundleExecutable = currInfoPlist.bundleExecutable {
                _ = Process().execute(chmodPath, workingDirectory: nil, arguments: ["755", appFilePath.appendPathComponent(bundleExecutable)])
            }
            
            //MARK: Change Application ID
            if newBundleID != "" {
                if let oldAppID = currInfoPlist.bundleIdentifier {
                    //  recursive func
                    func changeAppexID(_ appexFile: String) {
                        let appexPlist = PlistHelper(plistPath: appexFile + "/Info.plist")
                        if let appexBundleID = appexPlist.bundleIdentifier {
                            let newAppexID = "\(newBundleID)\(appexBundleID.substring(from: oldAppID.endIndex))"
                            setStatus("Changing \(appexFile) id to \(newAppexID)")
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

            
            //MARK: Codesigning - App
            let signableExtensions = ["dylib","so","0","vis","pvr","framework","appex","app"]
            recursiveDirectorySearch(appFilePath, extensions: signableExtensions, found: { file  in
                codeSign(file, certificate: signingCertificate, entitlements: entitlementsPlist)
            })
            codeSign(appFilePath, certificate: signingCertificate, entitlements: entitlementsPlist)
            
            
            //MARK: Codesigning - Verification
            let verificationTask = Process().execute(codesignPath, workingDirectory: nil, arguments: ["-v", appFilePath])
            if verificationTask.status != 0 {
                DispatchQueue.main.async(execute: {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.messageText = "Error verifying code signature!"
                    alert.informativeText = verificationTask.output
                    alert.alertStyle = .critical
                    alert.runModal()
                    //MARK: alert if certificate  expired
                    setStatus("Error verifying code signature")
                    Log.write(verificationTask.output)
                    self.cleanup(tempFolder); return
                })
            }
        }
        
        //MARK: Packaging
        //Check if output already exists and delete if so
        if fileManager.fileExists(atPath: outputFile) {
            do {
                try fileManager.removeItem(atPath: outputFile)
            } catch let error as NSError {
                setStatus("Error deleting output file")
                Log.write(error.localizedDescription)
                cleanup(tempFolder); return
            }
        }
        
        setStatus("Packaging IPA")
        Compress.shared.zip(workingDirectory, outputFile: outputFile)
        
        //MARK: Cleanup
        cleanup(tempFolder)
        setStatus("Done, output at \(outputFile)")
        
        if openByTerminal {
            NSWorkspace.shared.openFile(Log.logName)
            NSApp.terminate(self)
        }
    }

    
    //MARK: Codesigning
    func codeSign(_ file: String, certificate: String, entitlements: String?) {
        var arguments = ["-vvv","-fs",certificate,"--no-strict"]
        if fileManager.fileExists(atPath: entitlements!) {
            arguments.append("--entitlements=\(entitlements!)")
        }
        arguments.append(file)
        let codesignTask = Process().execute(codesignPath, workingDirectory: nil, arguments: arguments)
        
        if codesignTask.status != 0 {
            //MARK: alert if certificate expired
            setStatus("Error codesigning \(file)")
            Log.write(codesignTask.output)
        }
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
