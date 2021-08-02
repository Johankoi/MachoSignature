//
//  main.swift
//  CoolResign
//
//  Created by hanxiaoqing on 2018/5/17.
//  Copyright © 2018年 cheng. All rights reserved.
//
//https://github.com/stupergenius/Bens-Log/blob/master/blog-projects/swift-command-line/btc.swift
//https://github.com/kylef/Commander
import Foundation

class CommandWorker: NSObject {
    
    var inputPath: String?
    var profliePath: String?
    var cerName: String?
    var outputPath: String?
    var bundleID: String?
    
    func work() {
        let signer = CodeSigner()
        signer.delegate = self
        signer.sign(inputFile: inputPath!, provisioningFile: profliePath, newBundleID: bundleID ?? "", newDisplayName: "", newVersion: "", newShortVersion: "", signingCertificate: cerName!, outputFile: outputPath!, openByTerminal: true)
    }
}

extension CommandWorker: CodeSignDelegate {
    
    func codeSignBegin(workingDir: String) {
        print("CodeSign begin with workingDir: \(workingDir)")
    }
    
    func codeSignLogRecord(logDes: String) {
        print(logDes)
    }
    
    func codeSignError(errDes: String, tempDir: String) {
        print(errDes)
        cleanup(tempDir)
    }
    
    func codeSigneEndSuccessed(outPutPath: String, tempDir: String) {
        cleanup(tempDir)
        print("CodeSigneEndSuccessed, output at \(outPutPath)")
         exit(0)
    }
    
    func cleanup(_ dir: String) {
        do {
            print("Deleting: \(dir)")
            try FileManager.default.removeItem(atPath: dir)
        } catch {
            print("Deleting: \(dir) error")
        }
    }
}


let inputOpt = Option(trigger:.mixed("i","inputfile-path"))
let provisionOpt = Option(trigger:.mixed("p","provision-path"))
let cerNameOpt = Option(trigger:.mixed("c","certificate-name"))
let bundleIDOpt = Option(trigger:.mixed("b","bundleId"))
let outputOpt = Option(trigger:.mixed("o","outputfile-path"))

let helpOpt = Option(trigger:.mixed("h","help"))
let parser = OptionParser(definitions:[inputOpt, provisionOpt, cerNameOpt, bundleIDOpt,outputOpt,helpOpt])

let arguments = CommandLine.arguments
//let arguments = ["CoolResign", "-i", "/Users/hanxiaoqing/Documents/sdkTest_c.xcarchive", "-p", "/Users/hanxiaoqing/Desktop/SvnFolder/NewSDKFolder/provisioning/enterprise/DIS_ALL_NZK3GXHA6L.mobileprovision", "-c", "iPhone Distribution: Babeltime Inc.", "-o", "/Users/hanxiaoqing/Documents/sdkTest_c.ipa", "-b", "com.babeltime.sdkdemo.unity"]

print("get all args: \(arguments)")

let spliceArgs = arguments[1 ..< arguments.count]

do {
    let (options, rest) = try parser.parse(Array(spliceArgs))
    
    if spliceArgs.count == 0 || options[helpOpt] != nil {
        print(parser.helpStringForCommandName("show codesign important args"))
        exit(1)
    }
    
    let inputArgKeyCount = options.keys.count
    print("input argkey count: \(inputArgKeyCount)")
    
    // require arg: -i -p -c -o, the "-h, -b" two args neednt required
    if inputArgKeyCount < parser.definitions.count - 2 {
        print("Input arg keys not enough, Please check !!!")
        exit(2)
    }
    
    guard rest.count == inputArgKeyCount else {
        print("One or more arguments value not set, Please check !!!")
        exit(3)
    }
    
    let worker = CommandWorker()
    rest.forEach { argValue in
        let index = spliceArgs.index(of: argValue)
        let argKey = spliceArgs[index! - 1]
        
        if inputOpt.matches(argKey) {
            worker.inputPath = argValue
        }
        
        if provisionOpt.matches(argKey) {
            worker.profliePath = argValue
        }
        
        if cerNameOpt.matches(argKey) {
            worker.cerName = argValue
        }
        
        if bundleIDOpt.matches(argKey) {
            worker.bundleID = argValue
        }
        
        if outputOpt.matches(argKey) {
            worker.outputPath = argValue
        }
    
    }
    // 判断xcode-select -p是否有值
    // 判断 证书是否存在
    
    worker.work()
} catch let OptionKitError.invalidOption(description: description) {
    exit(4)
    print("OptionKit throw error: \n \(description)")
}





