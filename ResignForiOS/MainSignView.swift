//
//  MainSignView.swift
//  ResignForiOS
//
//  Created by hanxiaoqing on 2018/1/23.
//  Copyright © 2018年 cheng. All rights reserved.
//


import Cocoa

public extension NSPasteboard.PasteboardType {
    static var kUrl: NSPasteboard.PasteboardType {
        return self.init(kUTTypeURL as String)
    }
    static var kFilenames: NSPasteboard.PasteboardType {
        return self.init("NSFilenamesPboardType")
    }
    static var kFileUrl: NSPasteboard.PasteboardType {
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
    

    var provisioningProfiles: [ProvisioningProfile] = MobileProvisionProcessor().filterAll()
    var codesigningCerts: [String] = []
    
    var currSelectInput: String? = nil {
        didSet {
            if currSelectInput != oldValue {
                inputFileField.stringValue = currSelectInput ?? ""
            }
        }
    }
    
    var currSelectProfile: ProvisioningProfile? {
        didSet {
            newBundleIDField.stringValue = currSelectProfile?.bundleIdentifier ?? ""
        }
    }
    
    var currSelectCert: String? = nil
    var currSelectOutput: String?
    fileprivate var openByTerminal = false
    
    //MARK: Drag / Drop
    fileprivate var fileTypes: [String] = ["ipa","app","mobileprovision", "xcarchive"]
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
        case "ipa", "app", "xcarchive":
            currSelectInput = filePath
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
        setStatus("check XCode Task over")
    }
    
    
    func populateProvisioningProfiles() {
        var items = ["Re-Sign Only"]
        for profile in provisioningProfiles {
            items.append(profile.verboseOutput)
        }
        profileSelcetPop.removeAllItems()
        profileSelcetPop.addItems(withTitles:items)
        profileSelcetPop.selectItem(at: 1)
    }
    
    
    func populateCodesigningCerts() {
        codeSignCertsPop.removeAllItems()
        let securityResult = Process().execute(securityPath, workingDirectory: nil, arguments: ["find-identity","-v","-p","codesigning"])
        if securityResult.output.count < 1 {
            showCodesignCertsErrorAlert()
            return
        }        
        codesigningCerts = securityResult.output.split(separator: "\"").map{String($0)}.filter({ $0.contains("iPhone") || $0.contains("Apple Development") })
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
            updateAppleCer()
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
        var newBundleID :String = ""
        var newDisplayName :String = ""
        var newShortVersion :String = ""
        var newVersion :String = ""
        var inputFieldValue :String = ""
        
        DispatchQueue.main.sync {
            newBundleID = self.newBundleIDField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            newDisplayName = self.appDisplayName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            newShortVersion = self.appShortVersion.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            newVersion = self.appVersion.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            inputFieldValue = self.inputFileField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let inputFilePath :String = currSelectInput ?? inputFieldValue
        
        // check inputFile path is a dir, return directly
        if fileManager.fileExists(atPath: inputFilePath, isDirectory: nil) == false {
            DispatchQueue.main.async(execute: {
                let alert = NSAlert()
                alert.messageText = "Input file not found"
                alert.addButton(withTitle: "OK")
                alert.informativeText = "The file \(inputFilePath) could not be found"
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
        
        let signer = CodeSigner()
        signer.delegate = self
        if currSelectProfile == nil {
            DispatchQueue.main.sync {
                currSelectProfile = provisioningProfiles[self.profileSelcetPop.indexOfSelectedItem - 1]
            }
        }
        if currSelectCert == nil {
            DispatchQueue.main.sync {
                currSelectCert = self.codeSignCertsPop.selectedItem?.title
            }
        }
        signer.sign(inputFile: inputFilePath, provisioningFile: currSelectProfile, newBundleID: newBundleID, newDisplayName: newDisplayName, newVersion: newVersion, newShortVersion: newShortVersion, signingCertificate: currSelectCert!, outputFile: currSelectOutput!,openByTerminal: openByTerminal)
    }
    
    
    //MARK: IBActions
    @IBAction func chooseProvisioningProfile(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 0 {
//            newBundleIDField.isEditable = true
            newBundleIDField.stringValue = ""
        } else {
//            newBundleIDField.isEditable = false
            currSelectProfile = provisioningProfiles[sender.indexOfSelectedItem - 1]
            let matchCer = currSelectProfile?.developerCertificates.first
//            if let matchCer = matchCer, codesigningCerts.contains(matchCer) {
//                codeSignCertsPop.selectItem(withTitle: matchCer)
//                currSelectCert = matchCer
//            } else {
//                //MARK: todo  // 提醒用户没有匹配的证书
//            }
        }
    }
    
    @IBAction func selectInput(_ sender: AnyObject) {
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
    
    
    @IBAction func openOutputFile(_ sender: NSButton) {
        if let outputFile = self.currSelectOutput {
            if fileManager.fileExists(atPath: outputFile) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: outputFile)])
            }
        }
    }
    
    
    @IBAction func openLogFile(_ sender: Any) {
        NSWorkspace.shared.openFile(Log.logName)
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

extension MainSignView: CodeSignDelegate {
    
    func codeSignBegin(workingDir: String) {
        setStatus("CodeSign begin with workingDir: \(workingDir)")
        DispatchQueue.main.async {
            let hud = HProgregressHUD.showHUDAddedTo(view: self, animated: true)
            hud.label.stringValue = "CodeSigning"
        }
    }
    
    func codeSignLogRecord(logDes: String) {
        setStatus(logDes)
    }
    
    func codeSignError(errDes: String, tempDir: String) {
        setStatus(errDes)
        DispatchQueue.main.async {
            HProgregressHUD.HUDFor(view: self)?.hideAnimated(true)
        }
        cleanup(tempDir)
    }
    
    func codeSigneEndSuccessed(outPutPath: String, tempDir: String) {
        cleanup(tempDir)
        DispatchQueue.main.async {
            HProgregressHUD.HUDFor(view: self)?.hideAnimated(true)
        }
        setStatus("CodeSigneEndSuccessed, output at \(outPutPath)")
    }
    
    func cleanup(_ dir: String) {
        do {
            setStatus("Deleting: \(dir)")
            try fileManager.removeItem(atPath: dir)
        } catch {
            setStatus("Deleting: \(dir) error")
        }
    }
}
