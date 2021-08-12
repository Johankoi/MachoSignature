import Cocoa

fileprivate let HDefaultPadding: CGFloat = 4.0;
fileprivate let HDefaultLabelFontSize: CGFloat = 15.0;
fileprivate let HDefaultDetailsLabelFontSize: CGFloat = 12.0;


open class HProgregressHUD: NSView {
    
    public static func showHUDAddedTo(view: NSView, animated: Bool) -> HProgregressHUD {
        let hud = HProgregressHUD(with: view)
        view.addSubview(hud)
        hud.showAnimated(animated)
        return hud
    }
    
    public static func hideHUDFor(view: NSView, animated: Bool) -> Bool {
        if let hud = HUDFor(view: view) {
            hud.hideAnimated(animated)
            return true
        } else {
            return false
        }
    }
    
    public static func HUDFor(view: NSView) -> HProgregressHUD? {
        for view in view.subviews.reversed() {
            if view is HProgregressHUD {
                return view as? HProgregressHUD
            }
        }
        return nil
    }
    
    
    open func showAnimated(_: Bool)  {
        alphaValue = 1.0
        backgroundView.alphaValue = 0.4
    }
    
    open func hideAnimated(_: Bool)  {
        alphaValue = 0.0
        removeFromSuperview()
    }
    
    open func hideAnimated(_: Bool, afterDelay: Double)  {
        
    }
    
    open var contentColor: NSColor = .white
    
    public let backgroundView = HBackgroundView()
    
    public let bezelView = NSVisualEffectView()
    
    
    public let label: NSTextField = createLabel()
    public let detailsLabel: NSTextField = createLabel()

    
    fileprivate func commonInit() {
        alphaValue = 0.0
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        setupViews()
        updateIndicators()
    }
    
    public convenience init(with view: NSView) {
        self.init(frame: view.bounds)
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: CGRect())
        commonInit()
    }
    required public init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        commonInit()
    }
    open override var isFlipped: Bool {
        return true
    }
}

extension HProgregressHUD {
    
    fileprivate static func createLabel() -> NSTextField  {
        let label = NSTextField()
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        label.font = NSFont.systemFont(ofSize: 13.5)
        label.drawsBackground = false
        label.alignment = .center
        return label
    }
    

    fileprivate func setupViews() {
        let defaultColor = contentColor
        
        backgroundView.autoresizingMask = [.width, .height]
        backgroundView.backgroundColor = NSColor.gray
        backgroundView.alphaValue = 0.0
        addSubview(backgroundView)

        let materialView = HBackgroundView()
        materialView.autoresizingMask = [.width, .height]
        materialView.backgroundColor = NSColor.black
        materialView.alphaValue = 0.7
        
        label.textColor = defaultColor
        label.font = NSFont.boldSystemFont(ofSize: HDefaultLabelFontSize)
        materialView.addSubview(label)
        
        detailsLabel.textColor = defaultColor
        detailsLabel.font = NSFont.boldSystemFont(ofSize: HDefaultDetailsLabelFontSize)
        detailsLabel.alignment = .left
        materialView.addSubview(detailsLabel)
        
        bezelView.layer?.cornerRadius = 5.0
        bezelView.state = .active
        bezelView.blendingMode = .withinWindow
        bezelView.alphaValue = 0.7
        bezelView.addSubview(materialView)
        
        addSubview(bezelView)
    }
    
    
    fileprivate func updateIndicators() {
        
    }
    
    open override func layout() {
        super.layout()
        
        frame = (superview?.bounds)!
        backgroundView.frame = bounds
        
        let verticalMargin: CGFloat = 15.0
        let horizontalMargin: CGFloat = 15.0
        let limitMinWidth: CGFloat = 200
        
        label.left = 0.0
        label.top = verticalMargin
        label.width = limitMinWidth
        label.height = 20.0
        
        
        detailsLabel.top = label.bottom + verticalMargin
        let detailStringWidth = (detailsLabel.stringValue as NSString).size(withAttributes: [.font: detailsLabel.font]).width
        if detailStringWidth < limitMinWidth {
            detailsLabel.left = (limitMinWidth - detailStringWidth) * 0.5
            detailsLabel.width = detailStringWidth
            detailsLabel.height = 20.0
        } else {
            detailsLabel.left = horizontalMargin
            detailsLabel.width = limitMinWidth - detailsLabel.left * 2
            detailsLabel.height = heightFor(string: detailsLabel.stringValue, font: detailsLabel.font!, width: detailsLabel.width) + 8
        }
     
        bezelView.width = limitMinWidth
        bezelView.height = detailsLabel.bottom + verticalMargin
        
        if detailsLabel.stringValue.count == 0 || detailsLabel.isHidden  {
             bezelView.height = label.bottom + verticalMargin
        }
        
        // make the whole content view center
        bezelView.makeCenter()
    }
    
    func heightFor(string: String, font: NSFont, width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(string: string)
        let textContainer = NSTextContainer(containerSize: CGSize(width: width, height: CGFloat(MAXFLOAT)))
        
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        
        textStorage.addLayoutManager(layoutManager)
        textStorage.addAttributes([.font: font], range: NSRange(location: 0, length: textStorage.length))
        textContainer.lineFragmentPadding = 0.0
        
        layoutManager.glyphRange(for: textContainer)
        return layoutManager.usedRect(for: textContainer).size.height 
    }
    
    open override func mouseDown(with event: NSEvent) {}
    
}


fileprivate extension NSView {
    
    func makeCenter(in superView: NSView? = nil) {
        var x:CGFloat = 0
        var y:CGFloat = 0
        if let sv = superView {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
            y = CGFloat(roundf(Float((sv.frame.height - frame.height)/2.0)))
        } else if let sv = self.superview {
            x = CGFloat(roundf(Float((sv.frame.width - frame.width)/2.0)))
            y = CGFloat(roundf(Float((sv.frame.height - frame.height)/2.0)))
        }
        self.setFrameOrigin(NSMakePoint(x, y))
    }
    var left: CGFloat {
        get {
            return self.frame.origin.x
        }
        set(newLeft) {
            var frame = self.frame
            frame.origin.x = newLeft
            self.frame = frame
        }
    }
    
    var top:CGFloat {
        get {
            return self.frame.origin.y
        }
        
        set(newTop) {
            var frame = self.frame
            frame.origin.y = newTop
            self.frame = frame
        }
    }
    
    var width:CGFloat {
        get {
            return self.frame.size.width
        }
        
        set(newWidth) {
            var frame = self.frame
            frame.size.width = newWidth
            self.frame = frame
        }
    }
    
    var height:CGFloat {
        get {
            return self.frame.size.height
        }
        
        set(newHeight) {
            var frame = self.frame
            frame.size.height = newHeight
            self.frame = frame
        }
    }
    
    var right:CGFloat {
        get {
            return self.left + self.width
        }
    }
    
    var bottom:CGFloat {
        get {
            return self.top + self.height
        }
    }
}


open class HBackgroundView: NSView {
    
    public var backgroundColor: NSColor = NSColor.clear {
        didSet {
            if backgroundColor != oldValue {
                layer?.backgroundColor = backgroundColor.cgColor
            }
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required public init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        wantsLayer = true
    }
    open override var isFlipped: Bool {
        return true
    }
}

