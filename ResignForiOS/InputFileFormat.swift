//
//  InputFileFormat.swift
//  ResignForiOS
//
//  Created by hxq on 2021/8/2.
//  Copyright © 2021 cheng. All rights reserved.
//

import Foundation

public enum InputFileFormat {
    /// The format cannot be recognized or not supported yet.
    case unknown
    /// IPA file format.
    case IPA
    /// APP file format.
    case APP
    /// xcarchive file format.
    case XCARCHIVE
}


extension String {
    public var pathExtentionFormat: InputFileFormat {
        if self.isEmpty { return .unknown }
        switch self {
        case "ipa": return .IPA
        case "app": return .APP
        case "xcarchive": return .XCARCHIVE
        default:
            return .unknown
        }
    }
}

extension URL {
    public var fileFormat: InputFileFormat {
        return self.pathExtension.pathExtentionFormat;
    }
}
