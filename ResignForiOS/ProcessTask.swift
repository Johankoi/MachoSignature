//
//  ProcessTask.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//
import Foundation
struct AppSignerTaskOutput {
    var output: String
    var status: Int32
    init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
}
extension Process {
    func launchSyncronous() -> AppSignerTaskOutput {
        self.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        self.standardOutput = pipe
        self.standardError = pipe
        let pipeFile = pipe.fileHandleForReading
        self.launch()
        
        var outPutData = Data()
        while self.isRunning {
            outPutData.append(pipeFile.availableData)
        }
        
        pipeFile.closeFile();
        self.terminate();
    
        let output = String(data: outPutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppSignerTaskOutput(status: self.terminationStatus, output: output!)
    }
    
    func execute(_ launchPath: String, workingDirectory: String?, arguments: [String]?) -> AppSignerTaskOutput {
        self.launchPath = launchPath
        if arguments != nil {
            self.arguments = arguments
        }
        if workingDirectory != nil {
            self.currentDirectoryPath = workingDirectory!
        }
        return self.launchSyncronous()
    }
    
}
