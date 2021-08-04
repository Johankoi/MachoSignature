//
//  MobileProvisionProcessor.swift
//  ResignForiOS
//
//  Created by hxq on 2021/8/4.
//  Copyright © 2021 cheng. All rights reserved.
//

import Foundation


public final class MobileProvisionProcessor: CustomDebugStringConvertible, Equatable {
    
    //有效的未过期mobileProvision[] collection成 -> 名字数组
    //从mobileProvision名字获取mobileProvision 进而 得到 包含的证书信息类
    
    func installedMobileProvisions() -> [String] { return [""] }

    func mapProvisionToStringArray() -> [String] { return [""] }
    
    func developerCertificates(in: [String:String]) -> [String] { return [""] }
    
    
    public var debugDescription: String = ""
    
    public static func == (lhs: MobileProvisionProcessor, rhs: MobileProvisionProcessor) -> Bool {
        return true
    }
    

}
