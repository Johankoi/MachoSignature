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
        
        
        let randomFolder = UUID().uuidString
        do {
          let baseFolder = try Folder.temporary.createSubfolder(named: randomFolder)
          let basepath = baseFolder.path
            
            
        } catch {
            
        }
        

    }


}


