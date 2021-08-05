//
//  FileManager+Resign.swift
//  ResignForiOS
//
//  Created by hxq on 2021/8/2.
//  Copyright © 2021 cheng. All rights reserved.
//

import Foundation

// MARK: - File System Modification
extension FileManager {
    
    func createTemporaryDirectory(atPath path: String) throws -> URL {
           // let fileManager = FileManager.default
           let tempDirectoryURL   = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
           let tempExtractionURL  = tempDirectoryURL.appendingPathComponent(path)
           let tempExtractionPath = tempExtractionURL.path

           if self.fileExists(atPath: tempExtractionPath) {
               try self.removeItem(atPath: tempExtractionPath)
           }

           try self.createDirectory(atPath: tempExtractionPath, withIntermediateDirectories: false, attributes: nil)

           return tempExtractionURL
       }
    static var temporaryDirectoryPath: String {
        NSTemporaryDirectory()
    }

    static var temporaryDirectoryURL: URL {
        URL(fileURLWithPath: FileManager.temporaryDirectoryPath, isDirectory: true)
    }


    @discardableResult
    static func createDirectory(atPath path: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func createDirectory(at url: URL) -> Bool {
        createDirectory(atPath: url.path)
    }

    @discardableResult
    static func copyItem(atPath srcPath: String, toPath dstPath: String) -> Bool {
        do {
            try FileManager.default.copyItem(atPath: srcPath, toPath: dstPath)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func copyItem(atPath srcPath: URL, toPath dstPath: URL) -> Bool {
        copyItem(atPath: srcPath.path, toPath: dstPath.path)
    }
    
    
    @discardableResult
    static func removeItem(atPath path: String) -> Bool {
        do {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
                return true
            } else {
                return false
            }
        } catch {
            return false
        }
    }

    @discardableResult
    static func removeItem(at url: URL) -> Bool {
        removeItem(atPath: url.path)
    }

    @discardableResult
    static func removeAllItemsInsideDirectory(atPath path: String) -> Bool {
        let enumerator = FileManager.default.enumerator(atPath: path)
        var result = true

        while let fileName = enumerator?.nextObject() as? String {
            let success = removeItem(atPath: path + "/\(fileName)")
            if !success { result = false }
        }

        return result
    }

    @discardableResult
    static func removeAllItemsInsideDirectory(at url: URL) -> Bool {
        removeAllItemsInsideDirectory(atPath: url.path)
    }
}
