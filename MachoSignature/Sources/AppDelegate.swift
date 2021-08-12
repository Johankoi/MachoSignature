//
//  AppDelegate.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.windows.first?.makeKeyAndOrderFront(sender)
        return true
    }

}

