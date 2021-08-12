/**
*  Revamp
*  Copyright (c) Alvin John Pagente 2020
*  MIT license, see LICENSE file for details
*/

import Foundation
//==========================================================================
// MARK: Entitlements Constants Keys
//==========================================================================
//

//fileprivate let applicationIdentiferKey = "application-identifier"
//fileprivate let betaReportsActiveKey = "beta-reports-active"
//fileprivate let getTaskAllowKey = "get-task-allow"
//fileprivate let keychainAccessGroupsKey = "keychain-access-groups"
//fileprivate let teamIdKey = "com.apple.developer.team-identifier"
//
//// Push
//fileprivate let apsEnvironmentKey = "aps-environment"
//
//// iCloud
//fileprivate let ubiquityStoreIdentifierKey = "com.apple.developer.ubiquity-kvstore-identifier"


public struct Entitlements_ {
    private let readableKey = [
        "application-identifier":                        "App Identifier",
        "com.apple.developer.team-identifier":           "Team ID",
        "aps-environment":                               "Push Notification",
        "get-task-allow":                                "Debuggable",
        "com.apple.developer.nfc.readersession.formats": "NFC",
        "com.apple.security.application-groups":         "App Groups",
    ]
    private var rawDisplayable: [String: [String]] = [:] 

    public init(_ entitlements: [String: PropertyListDictionaryValue]) {
        for (key, value) in entitlements {
            rawDisplayable[key] = stringify(value)
        }
    }

    public func getRawEntitlements() -> [String: [String]] {
        return rawDisplayable
    }

    public func getDisplayableEntitlements() -> [String: String] {
        return displayable(from: rawDisplayable)
    }

    public func filterDisplayableEntitlements(with keys: [String]) -> [String: String] {
        var rawForm: [String: [String]] = [:]

        for key in keys {
            if let value = rawDisplayable[key] {
                rawForm[key] = value
            }
        }

        return displayable(from: rawForm)
    }

    private func displayable(from rawForm: [String: [String]]) -> [String: String] {
        var displayable: [String: String] = [:]

        for (key, var value) in rawForm {
            if value.isEmpty { value = ["Unknown"] }
            if let readable = readableKey[key] {
                displayable[readable] = value.joined(separator: ", ")
            } else {
                displayable[key] = value.joined(separator: ", ")
            }
        }

        return displayable
    }

    private func stringify(_ key: PropertyListDictionaryValue) -> [String] {
        switch key {
            case .string(let value):
                return [value]
            case .array(let values):
                var contents: [String] = []
                for value in values {
                    contents.append(contentsOf: stringify(value))
                }
                contents.sort()
                return contents
            case .bool(let value):
                return [String(value)]
            default:
                return []
        }
    }
}

/* NOTES from https://developer.apple.com/documentation/bundleresources/entitlements
 * 
 * key: aps-environment
 * type: String
 * description:
 * This key specifies whether to use the development or production Apple Push Notification service (APNs) environment 
 * when registering for push notifications. 
 *
 * key: com.apple.developer.nfc.readersession.formats 
 * type: array of strings
 * Possible Values
 *   TAG  - Allows read and write access to a tag using NFCTagReaderSession. 
 *   NDEF - The NFC Data Exchange Format.
 */
