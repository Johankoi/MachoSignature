//
//  PropertyListDictionaryValue.swift
//  MachoSignature
//
//  Created by skiven on 2021/8/15.
//

import Foundation


public enum PropertyListDictionaryValue: Hashable, Codable, Equatable {
    
    case string(String)
    case bool(Bool)
    case array([PropertyListDictionaryValue])
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([PropertyListDictionaryValue].self) {
            self = .array(array)
        } else {
            self = .unknown
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let string):
            try container.encode(string)
        case .bool(let bool):
            try container.encode(bool)
        case .array(let array):
            try container.encode(array)
        case .unknown:
            break
        }
        
    }
}
