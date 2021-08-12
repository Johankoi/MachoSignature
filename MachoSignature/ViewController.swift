//
//  ViewController.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//

import Cocoa
import Files

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let queryDic: CFDictionary = [
            kSecClass as String : kSecClassIdentity as String,
//            kSecMatchSubjectWholeString as String : subject,
//            kSecMatchTrustedOnly as String: isTrustedOnly,
            kSecMatchLimit as String: kSecMatchLimitAll as String,
            kSecReturnAttributes  as String : kCFBooleanTrue
//            kSecReturnRef as String : kCFBooleanTrue as Bool
            ] as CFDictionary
        
        var ref: CFTypeRef?
        
        SecItemCopyMatching(queryDic,&ref)
        
        if ref == nil{
            
        }else{
            let cers: [SecCertificate] = ref! as! [SecCertificate]
           
             cers.map({ cer  in
                
//                print(cer)
//               let cinfo = try? Certificate.parse(from: cer)
                
//                print(cinfo)
//                let cfValDic = SecCertificateCopyValues(cer, [kSecOIDX509V1SerialNumber] as CFArray, nil)!
//                let valDic: [String : [String: Any]] = cfValDic as! [String : [String: Any]]
//                let kValKey = kSecPropertyKeyValue as String
//                let serialNum = valDic[kSecOIDX509V1SerialNumber as String]![kValKey]! as! String
//                return serialNum == serialNumber
            })
            
        }
    }


}


