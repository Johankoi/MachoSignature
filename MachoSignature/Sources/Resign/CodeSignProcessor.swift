//
//  CodeSigner.swift
//  MachoSignature
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.

import Cocoa
import Files
import SwiftShell


public enum CodeSignProcessorError: Error {
    case inputFileNull
    case provisioningProfileNull
    case chmodFileFailed(file: String, stderr: String)
    case codeSignVerificationFailed(file: String, stderr: String)
    case codesignFailed(file: String, stderr: String)
}

extension CodeSignProcessorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .inputFileNull:
            return "input file is null, can not continue"
        case .provisioningProfileNull:
            return "provisioningProfile is null, can not continue to write entitlements plist"
        case .chmodFileFailed(let file, let stderr):
            return "execute to chmod file failed: \(file), shell stderr: \(stderr)"
        case .codeSignVerificationFailed(let file, let stderr):
            return "execute to codesign verification failed: \(file), shell stderr: \(stderr)"
        case .codesignFailed(let file, let stderr):
            return "execute to codesign failed: \(file), shell stderr: \(stderr)"
        }
    }
}


public enum CompressError: Error {
    case zipFileFailed(file: String, stderr: String)
    case unzipFileFailed(file: String, stderr: String)
}

extension CompressError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .zipFileFailed(let file, let stderr):
            return "execute to zip failed: \(file), shell stderr: \(stderr)"
        case .unzipFileFailed(let file, let stderr):
            return "execute to unzip failed: \(file), shell stderr: \(stderr)"
        }
    }
}


public extension Folder {
    /// Search for subfolders by providing the expected folder extensions
    func findSubfolders(withExtension extensions: [String]) -> [Folder] {
        let folders = self.subfolders.recursive
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
    
    func zip(input: String, output: String) throws {
        main.currentdirectory = input
        let zipTask = SwiftShell.run("/usr/bin/zip", "-qry", output, ".")
        if zipTask.exitcode != 0 {
            throw CompressError.zipFileFailed(file: input, stderr: zipTask.stderror)
        }
    }
    
    func unzip(input: String, output: String) throws {
        let unzipTask = SwiftShell.run("/usr/bin/unzip", "-q", input, "-d", output)
        if unzipTask.exitcode != 0 {
            throw CompressError.unzipFileFailed(file: input, stderr: unzipTask.stderror)
        }
    }
}

protocol CodeSignDelegate {
    func codeSignBegin(workingDir: String)
    func codeSignLogRecord(logDes: String)
    func codeSigneEndSuccessed(outPutPath: String, tempDir: String)
    func codeSignError(errDes: String, tempDir: String)
}

class CodeSignProcessor {
    var delegate: CodeSignDelegate?
    
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

    func sign(filePath: String?, provision: ProvisioningProfile?,
              newBundleID: String, newDisplayName: String,
              newVersion: String, newShortVersion: String,
              certificate: String, outputPath: String) throws {
        
        guard let filePath = filePath, !filePath.isEmpty else {
            throw CodeSignProcessorError.inputFileNull
        }
        
        guard let provision = provision else {
            throw CodeSignProcessorError.provisioningProfileNull
        }
        
        let payloadFolder = try outputFolder.createSubfolder(named: "Payload")
        let entitlementsPath = tempFolder.path + "entitlements.plist"
        
        switch filePath.pathExtension.pathExtentionFormat {
        case .IPA:
            try Compress.shared.unzip(input: filePath, output: outputFolder.path)
        case .APP:
            let appFolder = try Folder(path: filePath)
            try appFolder.copy(to: payloadFolder)
        case .XCARCHIVE:
            let products = try Folder(path: filePath + "/Products/Applications/")
            let appFolder = products.findSubfolders(withExtension: ["app"]).last
            try appFolder?.copy(to: payloadFolder)
        case .unknown: break
        }
        
        try provision.writeEntitlementsPlist(to: entitlementsPath)
        
        var foldersToSign = payloadFolder.findSubfolders(withExtension: ["app", "appex", "framework"])
        foldersToSign.append(foldersToSign.filter { $0.url.pathExtension == "app" }.last!)
        let firstIndex = foldersToSign.firstIndex{ $0.url.pathExtension == "app" }!
        foldersToSign.remove(at: firstIndex);
        
        var failed = false
        for folder in foldersToSign {
            if folder.containsFile(named: "Info.plist") {
                var bundleIdToChange = newBundleID
                let plistFile = try folder.file(named: "Info.plist")
                let plistProcessor = PropertyListProcessor(with: plistFile.path)
                let bundleExecutable = plistProcessor.content.bundleExecutable
                let executablePath = folder.path.appendPathComponent(bundleExecutable)
                
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
                
                let result = codeSign(executablePath, certificate: certificate, entitlements: entitlementsPath)
                if case .failure(let err) = result {
                    print(err.localizedDescription)
                    failed = true
                    break
                }
            }
        }
        if failed == false {
            try Compress.shared.zip(input: outputFolder.path, output: outputPath)
            try baseFolder.empty()
        }
    }


    func codeSign(_ file: String, certificate: String, entitlements: String?) -> Result<String, Error> {
 
        let chmodTask = SwiftShell.run("/bin/chmod", "755", file)
        if chmodTask.exitcode != 0 {
            return .failure(CodeSignProcessorError.chmodFileFailed(file: file, stderr: chmodTask.stderror))
        }

        var arguments = ["-vvv", "-fs", certificate, "--no-strict"]
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: entitlements!) {
            arguments.append("--entitlements=\(entitlements!)")
        }
        arguments.append(file)

        let codesignTask = runAsync("/usr/bin/codesign", arguments).onCompletion { command in
            print("finshed codesign command")
        }
        do {
            try codesignTask.finish()
        } catch {
            let codesignError = CodeSignProcessorError.codesignFailed(file: file, stderr: error.localizedDescription)
            return .failure(codesignError)
        }
        
        let verificateTask = SwiftShell.run("/usr/bin/codesign", "-v", file)
        if verificateTask.exitcode != 0 {
            return .failure(CodeSignProcessorError.codeSignVerificationFailed(file: file, stderr: verificateTask.stderror))
        }
        return .success(file);
    }
}
