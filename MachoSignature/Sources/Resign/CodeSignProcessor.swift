//
//  CodeSigner.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.

import Cocoa
import Files

public extension Folder {
    /// Search for subfolders by providing the expected folder extensions
    func findSubfolders(withExtension extensions: [String]) -> [Folder] {
        let folders        = self.subfolders.recursive
        var matchedFolders = [Folder]()
        
        for folder in folders {
            for suffix in extensions {
                if folder.name.hasSuffix(suffix) {
                    matchedFolders.append(folder)
                }
            }
        }
        return matchedFolders
    }
}

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

protocol CodeSignDelegate {
    func codeSignBegin(workingDir: String)
    func codeSignLogRecord(logDes: String)
    func codeSigneEndSuccessed(outPutPath: String, tempDir: String)
    func codeSignError(errDes: String, tempDir: String)
}

class CodeSignProcessor {
    var delegate: CodeSignDelegate?
    let chmodPath = "/bin/chmod"
    let codesignPath = "/usr/bin/codesign"
    
    public var baseFolder   : Folder
    public var outputFolder : Folder
    public var inputFolder  : Folder
    public var tempFolder   : Folder
    
    init() throws {
        let budleId = Bundle.main.bundleIdentifier ?? "resign.working.place"
        baseFolder   = try Folder.temporary.createSubfolder(named: budleId + "/\(UUID().uuidString)")
        tempFolder   = try baseFolder.createSubfolder(named: "temp")
        outputFolder = try baseFolder.createSubfolder(named: "out")
        inputFolder  = try baseFolder.createSubfolder(named: "in")
    }
    
    /// 错误判断： 1. 描述文件，证书信息不匹配
    func sign(inputFile: String, provisioningFile: ProvisioningProfile?,
              newBundleID: String,newDisplayName: String,
              newVersion: String, newShortVersion: String,
              signingCertificate: String, outputFile: String) throws {
        let payloadFolder = try outputFolder.createSubfolder(named: "Payload")
        let entitlementsPath = tempFolder.path + "entitlements.plist"
        
        switch inputFile.pathExtension.pathExtentionFormat {
        case .IPA:
            Compress.shared.unzip(inputFile, outputPath: outputFolder.path)
        case .APP:
            let appFolder = try Folder(path: inputFile)
            try appFolder.copy(to: payloadFolder)
        case .XCARCHIVE:
            let products = try Folder(path: inputFile + "/Products/Applications/")
            let appFolder = products.findSubfolders(withExtension: ["app"]).last
            try appFolder?.copy(to: payloadFolder)
        case .unknown: break
        }
        
        
        try provisioningFile?.writeEntitlementsPlist(to: entitlementsPath)
        
        var foldersToSign = payloadFolder.findSubfolders(withExtension: ["app", "appex", "framework"])
        foldersToSign.append(foldersToSign.filter { $0.url.pathExtension == "app" }.last!)
        let firstIndex = foldersToSign.firstIndex{ $0.url.pathExtension == "app" }!
        foldersToSign.remove(at: firstIndex);
        
        
        for folder in foldersToSign {
            print(folder.path)
            if folder.containsFile(named: "Info.plist") {
                var bundleIdToChange = newBundleID
                let plistFile = try folder.file(named: "Info.plist")
                let plistProcessor = PropertyListProcessor(with: plistFile.path)
                let bundleExecutable = plistProcessor.content.bundleExecutable
                let executablePath = folder.path.appendPathComponent(bundleExecutable)
                
                print("bundleExecutable: \(bundleExecutable)")
                
                if folder.url.pathExtension == "app"  {
                    plistProcessor.modifyBundleIdentifier(with: bundleIdToChange)
                    plistProcessor.modifyBundleName(with: newDisplayName)
                    plistProcessor.modifyBundleVersion(with: newVersion)
                    plistProcessor.modifyBundleVersionShort(with: newShortVersion)
                    plistProcessor.delete(key: InfoPlist.CodingKeys.bundleResourceSpecification.rawValue)
                    
                } else if folder.url.pathExtension == "appex"  {
                    let oldBundleId = plistProcessor.content.bundleIdentifier;
                    let appexName = oldBundleId.components(separatedBy: ".").last!
                    bundleIdToChange = "\(newBundleID).\(appexName)"
                    plistProcessor.modifyBundleIdentifier(with: bundleIdToChange)
                }
                codeSign(executablePath, certificate: signingCertificate, entitlements: entitlementsPath)
            }
        }
        
        delegate?.codeSignLogRecord(logDes: "Packaging IPA: \(outputFile)")
        Compress.shared.zip(outputFolder.path, outputFile: outputFile)
        try baseFolder.empty()
    }
    
    
    //MARK: Codesigning
    func codeSign(_ file: String, certificate: String, entitlements: String?) {
        delegate?.codeSignLogRecord(logDes: "codeSign:\(file)")
        // Make sure that the executable is well executable.
        _ = Process().execute(chmodPath, workingDirectory: nil, arguments: ["755", file])
        
        var arguments = ["-vvv","-fs",certificate,"--no-strict"]
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: entitlements!) {
            arguments.append("--entitlements=\(entitlements!)")
        }
        arguments.append(file)
        let codesignTask = Process().execute(codesignPath, workingDirectory: nil, arguments: arguments)
        
        let verificationTask = Process().execute(codesignPath, workingDirectory: nil, arguments: ["-v", file])
        if verificationTask.status != 0 {
            //MARK: alert if certificate  expired
//              self.delegate?.codeSignError(errDes: "verifying code sign fail:\(verificationTask.output)", tempDir: tempFolder)
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
        
        if codesignTask.status != 0 {
            //MARK: alert if certificate expired
            delegate?.codeSignLogRecord(logDes: "Error codesigning \(file) error:\(codesignTask.output)")
        }
        
        
        
    }
}
