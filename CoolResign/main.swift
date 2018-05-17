//
//  main.swift
//  CoolResign
//
//  Created by hanxiaoqing on 2018/5/17.
//  Copyright © 2018年 cheng. All rights reserved.
//

import Foundation

print("begin test Option")
//https://github.com/stupergenius/Bens-Log/blob/master/blog-projects/swift-command-line/btc.swift

let inputOpt = Option(trigger:.mixed("i","inputfile-path"))
let provisionOpt = Option(trigger:.mixed("p","provision-path"))
let cerNameOpt = Option(trigger:.mixed("c","certificate-name"))
let bundleIDOpt = Option(trigger:.mixed("b","bundleId"))
let outputOpt = Option(trigger:.mixed("o","outputfile-path"))
let helpOpt = Option(trigger:.mixed("h","help"))
let parser = OptionParser(definitions:[inputOpt, provisionOpt, cerNameOpt, bundleIDOpt,outputOpt])

let arguments = CommandLine.arguments
let spliceArgs = arguments[1 ..< arguments.count]

do {
    let (options, rest) = try parser.parse(Array(spliceArgs))
    
    if options[inputOpt] != nil {
        
        parser.normalizeParameter
        print("\(rest)")
    }
    
    if options[provisionOpt] != nil {
        print("\(rest)")
    }
    
    if options[cerNameOpt] != nil {
        print("\(rest)")
    }
    
    
    if options[helpOpt] != nil {
        print(parser.helpStringForCommandName("optionTest"))
    }
} catch let OptionKitError.invalidOption(description: description) {
    print(description)
}




class CommandWorker: NSObject {
    
    var inputPath: String?
    var profliePath: String?
    var cerName: String?
    var outputPath: String?
    
    func work()  {
        
        let args = CommandLine.arguments
//        let args = ["CoolResign", "-i", "/Users/hanxiaoqing/Documents/sdkTest_c.xcarchive", "-p", "/Users/hanxiaoqing/Desktop/SvnFolder/NewSDKFolder/provisioning/enterprise/DIS_ALL_NZK3GXHA6L.mobileprovision", "-c", "iPhone Distribution: Babeltime Inc.", "-o", "/Users/hanxiaoqing/Documents/sdkTest_c.ipa"]
        
        print("begin print args = \(args)")
        
        if args.count > 3 {
            
            if let pindex = args.index(of: "-i") {
                inputPath = args[pindex + 1]
            }
            print("-i arg value \(inputPath)")
            
            
            
            if let pindex = args.index(of: "-p") {
                profliePath = args[pindex + 1]
            }
            print("-p arg value \(profliePath)")
            
            
            if let pindex = args.index(of: "-c") {
                cerName = args[pindex + 1]
            }
            print("-c arg value \(cerName)")
            
            
            if let pindex = args.index(of: "-o") {
                outputPath = args[pindex + 1]
            }
            print("-o arg value \(outputPath)")
            
            let signer = CodeSigner()
            signer.delegate = self
            signer.sign(inputFile: inputPath!, provisioningFile: profliePath, newBundleID: "", newDisplayName: "", newVersion: "", newShortVersion: "", signingCertificate: cerName!, outputFile: outputPath!, openByTerminal: true)
        }
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

//CommandWorker().work()



