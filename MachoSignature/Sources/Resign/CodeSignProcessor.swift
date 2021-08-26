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
    case outputPathNull
    case provisioningProfileNull
    case certificateNull
    case entitlementsPathNotExist
    case chmodFileFailed(file: String, stderr: String)
    case codeSignVerificationFailed(file: String, stderr: String)
    case codesignFailed(file: String, stderr: String)
}

extension CodeSignProcessorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .inputFileNull:
            return "input file is null, can not continue."
        case .outputPathNull:
            return "output path is null, can not continue after resign."
        case .provisioningProfileNull:
            return "provisioningProfile is null, can not continue to write entitlements plist."
        case .certificateNull:
            return "certificate is null, can not continue to resign."
        case .entitlementsPathNotExist:
            return "entitlements plist path not exist, can not continue to resign."
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
              bundleID: String?, displayName: String?,
              version: String?, shortVersion: String?,
              certificate: String?, outputPath: String?) throws {
        
        guard let filePath = filePath, !filePath.isEmpty else {
            throw CodeSignProcessorError.inputFileNull
        }
        
        guard let outputPath = outputPath, !outputPath.isEmpty else {
            throw CodeSignProcessorError.outputPathNull
        }
        
        guard let provision = provision else {
            throw CodeSignProcessorError.provisioningProfileNull
        }
        
        
        guard let certificate = certificate, !certificate.isEmpty else {
            throw CodeSignProcessorError.certificateNull
        }
        
        // undo 检查provision的证书信息 与 certificate 是否对应上？？
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
                let plistFile = try folder.file(named: "Info.plist")
                let plistProcessor = PropertyListProcessor(with: plistFile.path)
                let bundleExecutable = plistProcessor.content.bundleExecutable
                let executablePath = folder.path.appendPathComponent(bundleExecutable)
                
                if folder.url.pathExtension == "app"  {
                    plistProcessor.modifyBundleIdentifier(with: bundleID)
                    plistProcessor.modifyBundleName(with: displayName)
                    plistProcessor.modifyBundleVersion(with: version)
                    plistProcessor.modifyBundleVersionShort(with: shortVersion)
                    plistProcessor.delete(key: InfoPlist.CodingKeys.bundleResourceSpecification.rawValue)
                    
                } else if folder.url.pathExtension == "appex"  {
                    let oldBundleId = plistProcessor.content.bundleIdentifier;
                    let appexName = oldBundleId.components(separatedBy: ".").last!
                    if var bundleIdToChange = bundleID {
                        bundleIdToChange = "\(bundleIdToChange).\(appexName)"
                        plistProcessor.modifyBundleIdentifier(with: bundleIdToChange)
                    }
                }
                
                let result = codeSignInner(executablePath, certificate, entitlementsPath)
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
    
    
    private func codeSignInner(_ file: String, _ certificate: String, _ entitlements: String) -> Result<String, Error> {
        
        var arguments = ["-vvv", "-fs", certificate, "--no-strict"]

        let chmodTask = SwiftShell.run("/bin/chmod", "755", file)
        if chmodTask.exitcode != 0 {
            return .failure(CodeSignProcessorError.chmodFileFailed(file: file, stderr: chmodTask.stderror))
        }
        
        if FileManager.default.fileExists(atPath: entitlements) {
            arguments.append("--entitlements=\(entitlements)")
        } else {
            return .failure(CodeSignProcessorError.entitlementsPathNotExist)
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
