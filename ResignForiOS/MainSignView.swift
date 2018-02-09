//
//  MainSignView.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//


import Cocoa

public extension NSPasteboard.PasteboardType {
    public static var kUrl: NSPasteboard.PasteboardType {
        return self.init(kUTTypeURL as String)
    }
    public static var kFilenames: NSPasteboard.PasteboardType {
        return self.init("NSFilenamesPboardType")
    }
    public static var kFileUrl: NSPasteboard.PasteboardType {
        return self.init(kUTTypeFileURL as String)
    }
}


class MainSignView: NSView {
    
    let securityPath = "/usr/bin/security"
    let defaults = UserDefaults()
    let fileManager = FileManager.default
    
    
    //MARK: IBOutlets
    @IBOutlet var inputFileField: NSTextField!
    
    @IBOutlet var profileSelcetPop: NSPopUpButton!
    @IBOutlet var codeSignCertsPop: NSPopUpButton!
    
    @IBOutlet var newBundleIDField: NSTextField!
    @IBOutlet var appDisplayName: NSTextField!
    @IBOutlet var appShortVersion: NSTextField!
    @IBOutlet var appVersion: NSTextField!
    
    @IBOutlet var StartButton: NSButton!
    @IBOutlet var StatusLabel: NSTextField!
    
    //MARK: Variables
    var provisioningProfiles: [Profile] = ProfileManager().updateProfiles()
    var codesigningCerts: [String] = []
    
    var currSelectInput: String? = nil {
        didSet {
            if currSelectInput != oldValue {
                inputFileField.stringValue = currSelectInput ?? ""
            }
        }
    }
    
    var currSelectProfile: Profile? {
        didSet {
            newBundleIDField.stringValue = currSelectProfile?.bundleID ?? ""
        }
    }
    
    var currSelectCert: String? = nil
    var currSelectOutput: String?
    fileprivate var openByTerminal = false
    
    //MARK: Drag / Drop
    fileprivate var fileTypes: [String] = ["ipa","app","mobileprovision"]
    fileprivate var fileTypeIsOk = false
    
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if checkExtension(sender) == true {
            fileTypeIsOk = true
            return .copy
        } else {
            fileTypeIsOk = false
            return NSDragOperation()
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if fileTypeIsOk {
            return .copy
        } else {
            return NSDragOperation()
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard()
        if let board = pasteboard.propertyList(forType: .kFilenames) as? NSArray {
            if let filePath = board[0] as? String {
                fileDropped(filePath)
                return true
            }
        }
        return false
    }
    
    func checkExtension(_ drag: NSDraggingInfo) -> Bool {
        if let board = drag.draggingPasteboard().propertyList(forType: .kFilenames) as? NSArray,
            let path = board[0] as? String {
            return fileTypes.contains(path.pathExtension.lowercased())
        }
        return false
    }
    
    
    func fileDropped(_ filePath: String) {
        switch filePath.pathExtension.lowercased() {
        case "ipa", "app":
            inputFileField.stringValue = filePath
            break
        default: break
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        populateProvisioningProfiles()
        populateCodesigningCerts()
        
        setStatus("Ready")
        
        let xcsCmd = "/usr/bin/xcode-select"
        let checkCodeTask = Process().execute(xcsCmd, workingDirectory: nil, arguments: ["-p"])
        if checkCodeTask.status != 0 {
            _ = Process().execute(xcsCmd, workingDirectory: nil, arguments: ["--install"])
            NSApplication.shared.terminate(self)
        }
        var inputPath: String?
        var proflie: Profile?
        var cerName: String?
        var outputPath: String?
        
        let args = CommandLine.arguments
        if args.count > 3 {
            openByTerminal = true
            StatusLabel.stringValue = "openByTerminal"
            if let pindex = args.index(of: "-i") {
                inputPath = args[pindex + 1]
            }
            if let pindex = args.index(of: "-p") {
                let profliePath = args[pindex + 1]
                proflie = Profile(filePath: profliePath)
            }
            if let pindex = args.index(of: "-c") {
                cerName = args[pindex + 1]
            }
            if let pindex = args.index(of: "-o") {
                outputPath = args[pindex + 1]
            }
            
            currSelectInput = inputPath ?? nil
            currSelectProfile = proflie
            currSelectCert = cerName ?? nil
            currSelectOutput = outputPath
            
            NSWorkspace.shared.openFile(Log.logName)
            Thread.detachNewThreadSelector(#selector(self.signingThread), toTarget: self, with: nil)
        }
    }
    
    
    func populateProvisioningProfiles() {
        var items = ["Re-Sign Only"]
        for profile in provisioningProfiles {
            items.append("\(profile.name) (\(profile.teamIdentifiers.first!))")
        }
        profileSelcetPop.removeAllItems()
        profileSelcetPop.addItems(withTitles:items)
        profileSelcetPop.selectItem(at: 0)
    }
    
    
    func populateCodesigningCerts() {
        codeSignCertsPop.removeAllItems()
        let securityResult = Process().execute(securityPath, workingDirectory: nil, arguments: ["find-identity","-v","-p","codesigning"])
        if securityResult.output.count < 1 {
            showCodesignCertsErrorAlert()
            return
        }
        codesigningCerts = securityResult.output.components(separatedBy: "\"").filter({ $0.contains("iPhone")})
        for cert in self.codesigningCerts {
            codeSignCertsPop.addItem(withTitle: cert)
        }
    }
    
    
    func showCodesignCertsErrorAlert(){
        let alert = NSAlert()
        alert.messageText = "No codesigning certificates found"
        alert.informativeText = "I can attempt to fix this automatically, would you like me to try?"
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        if alert.runModal() == .alertFirstButtonReturn {
            fixSigning()
            populateCodesigningCerts()
        }
    }
    
    
    @IBAction func doSign(_ sender: NSButton) {
        if codesigningCerts.count == 0 {
            showCodesignCertsErrorAlert()
        } else {
            NSApplication.shared.windows[0].makeFirstResponder(self)
            let saveDialog = NSSavePanel()
            saveDialog.allowedFileTypes = ["ipa","app"]
            saveDialog.nameFieldStringValue = inputFileField.stringValue.lastPathComponent.deletePathExtension
            if saveDialog.runModal() == .OK {
                currSelectOutput = saveDialog.url!.path
                Thread.detachNewThreadSelector(#selector(self.signingThread), toTarget: self, with: nil)
            } else {
                currSelectOutput = nil
            }
        }
    }
    
    
    @objc func signingThread() {
        
        //MARK: Set up variables
        var newBundleID : String = ""
        var newDisplayName : String = ""
        var newShortVersion : String = ""
        var newVersion : String = ""
        
        DispatchQueue.main.sync {
            newBundleID = self.newBundleIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            newDisplayName = self.appDisplayName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            newShortVersion = self.appShortVersion.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            newVersion = self.appVersion.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        //MARK: Sanity checks
        
        // check inputFile path is a dir, return directly
        var inputIsDir: ObjCBool = false
        let inputExists = fileManager.fileExists(atPath: currSelectInput!, isDirectory: &inputIsDir)
        if  inputIsDir.boolValue {
            setStatus("input can not be a Directory")
            //return
        }
        if inputExists == false {
            DispatchQueue.main.async(execute: {
                let alert = NSAlert()
                alert.messageText = "Input file not found"
                alert.addButton(withTitle: "OK")
                alert.informativeText = "The file \(self.currSelectInput!) could not be found"
                alert.runModal()
            })
            return
        }
        
        // Check provisioningFile
        if let currProfile = currSelectProfile {
            if currProfile.isExpired == true {
                setStatus("Provisioning profile expired")
                return
            }
        }

        CodeSigner().sign(inputFile: currSelectInput!, provisioningFile: currSelectProfile?.filePath, newBundleID: newBundleID, newDisplayName: newDisplayName, newVersion: newVersion, newShortVersion: newShortVersion, signingCertificate: currSelectCert!, outputFile: currSelectOutput!,openByTerminal: openByTerminal)
    }
    
    
    //MARK: IBActions
    @IBAction func chooseProvisioningProfile(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 0 {
            newBundleIDField.isEditable = true
            newBundleIDField.stringValue = ""
        } else {
            newBundleIDField.isEditable = false
            currSelectProfile = provisioningProfiles[sender.indexOfSelectedItem - 1]
            let matchCer = currSelectProfile?.developerCertificates.first
            if let matchCer = matchCer, codesigningCerts.contains(matchCer) {
                codeSignCertsPop.selectItem(withTitle: matchCer)
                currSelectCert = matchCer
            } else {
                //MARK: todo  // 提醒用户没有匹配的证书
            }
        }
    }
    
    @IBAction func doBrowse(_ sender: AnyObject) {
        let openDialog = NSOpenPanel()
        openDialog.canChooseFiles = true
        openDialog.canChooseDirectories = false
        openDialog.allowsMultipleSelection = false
        openDialog.allowsOtherFileTypes = false
        openDialog.allowedFileTypes = ["ipa", "IPA", "app", "APP", "xcarchive"]
        openDialog.runModal()
        if let filename = openDialog.urls.first {
            currSelectInput = filename.path
        }
    }
    
    
    @IBAction func chooseSigningCertificate (_ sender: NSPopUpButton) {
        currSelectCert = sender.selectedItem?.title
        setStatus("Set currSelectCert: \(currSelectCert!)")
    }
    
    
    @IBAction func statusLabelClick(_ sender: NSButton) {
        if let outputFile = self.currSelectOutput {
            if fileManager.fileExists(atPath: outputFile) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: outputFile)])
            }
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.string, .tiff, .kUrl, .kFilenames])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.string, .tiff, .kUrl, .kFilenames])
    }
    
}

