import Cocoa
import FlutterMacOS

let kEventOnTrayIconMouseDown = "onTrayIconMouseDown"
let kEventOnTrayIconMouseUp = "onTrayIconMouseUp"
let kEventOnTrayIconRightMouseDown = "onTrayIconRightMouseDown"
let kEventOnTrayIconRightMouseUp = "onTrayIconRightMouseUp"
let kEventOnTrayMenuItemClick = "onTrayMenuItemClick"

extension NSRect {
    var topLeft: CGPoint {
        set {
            let screenFrameRect = NSScreen.main!.frame
            origin.x = newValue.x
            origin.y = screenFrameRect.height - newValue.y - size.height
        }
        get {
            let screenFrameRect = NSScreen.main!.frame
            return CGPoint(x: origin.x, y: screenFrameRect.height - origin.y - size.height)
        }
    }
}

public class TrayManagerPlugin: NSObject, FlutterPlugin, NSMenuDelegate {
    var channel: FlutterMethodChannel!
    
    var statusItem: NSStatusItem?
    var trayMenu: TrayMenu?
    var iconPosition: NSControl.ImagePosition = .imageLeft
    var lastTitle: String = ""
    var textAttributes: [NSAttributedString.Key : Any]?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tray_manager", binaryMessenger: registrar.messenger)
        let instance = TrayManagerPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "destroy":
            destroy(call, result: result)
            break
        case "getBounds":
            getBounds(call, result: result)
            break
        case "setIcon":
            setIcon(call, result: result)
            break
        case "setIconPosition":
            setIconPosition(call, result: result)
            break
        case "setToolTip":
            setToolTip(call, result: result)
            break
        case "setTitle":
            setTitle(call, result: result)
            break
        case "setContextMenu":
            setContextMenu(call, result: result)
            break
        case "popUpContextMenu":
            popUpContextMenu(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    //    private func _init() {
    //        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    //        if let button = statusItem.button {
    //            button.action = #selector(self.statusItemButtonClicked(sender:))
    //            button.target = self
    //            button.sendAction(on: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp])
    //            _inited = true
    //        }
    //    }
    
    @objc func statusItemButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        var methodName: String?
        
        switch event.type {
        case NSEvent.EventType.leftMouseDown:
            methodName = kEventOnTrayIconMouseDown
            break
        case NSEvent.EventType.leftMouseUp:
            methodName = kEventOnTrayIconMouseUp
            break
        case NSEvent.EventType.rightMouseDown:
            methodName = kEventOnTrayIconRightMouseDown
            break
        case NSEvent.EventType.rightMouseUp:
            methodName = kEventOnTrayIconRightMouseUp
            break
        default:
            break
        }
        if (methodName != nil) {
            channel.invokeMethod(methodName!, arguments: nil, result: nil)
        }
    }

    private func ensureStatusItem() {
        if statusItem != nil {
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.maximumLineHeight = 9
        paragraphStyle.minimumLineHeight = 9
        paragraphStyle.alignment = .right
        paragraphStyle.lineBreakMode = .byClipping
        textAttributes = [
            .paragraphStyle: paragraphStyle,
            .font: NSFont.systemFont(ofSize: 8.75),
            .foregroundColor: NSColor.labelColor
        ]
        if let button = statusItem?.button {
            button.target = self
            button.action = #selector(statusItemButtonClicked(sender:))
            button.sendAction(on: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp])
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = iconPosition
        }
    }

    private func updateImagePosition(for title: String) {
        guard let button = statusItem?.button else {
            return
        }
        if title.isEmpty {
            button.imagePosition = .imageOnly
        } else {
            button.imagePosition = iconPosition
        }
    }

    private func imagePosition(from value: String) -> NSControl.ImagePosition {
        switch value {
        case "right":
            return .imageRight
        default:
            return .imageLeft
        }
    }
    
    public func destroy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (statusItem != nil) {
            NSStatusBar.system.removeStatusItem(statusItem!)
        }
        statusItem = nil
        trayMenu = nil
        lastTitle = ""
        result(true)
    }
    
    public func getBounds(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let frame = statusItem?.button?.window?.frame;
        
        if (frame != nil) {
            let resultData: NSDictionary = [
                "x": frame!.topLeft.x,
                "y": frame!.topLeft.y,
                "width": frame!.size.width,
                "height": frame!.size.height,
            ]
            result(resultData)
        } else {
            result(nil)
        }
    }
    
    public func setIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let base64Icon: String =  args["base64Icon"] as! String;
        let isTemplate: Bool =  args["isTemplate"] as! Bool;
        let iconPosition: String =  args["iconPosition"] as! String;
        let iconSize: Int = args["iconSize"] as! Int;
        
        let imageData = Data(base64Encoded: base64Icon, options: .ignoreUnknownCharacters)
        let image = NSImage(data: imageData!)
        image!.size = NSSize(width: iconSize, height: iconSize)
        image!.isTemplate = isTemplate

        ensureStatusItem()
        self.iconPosition = imagePosition(from: iconPosition)
        if let button = statusItem?.button {
            button.image = image
        }
        updateImagePosition(for: lastTitle)
        
        result(true)
    }
    
    public func setIconPosition(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let iconPosition: String =  args["iconPosition"] as! String;

        ensureStatusItem()
        self.iconPosition = imagePosition(from: iconPosition)
        updateImagePosition(for: lastTitle)
        
        result(true)
    }
    
    public func setToolTip(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let toolTip: String =  args["toolTip"] as! String;

        ensureStatusItem()
        if let button = statusItem?.button {
            button.toolTip = toolTip
        }
        
        result(true)
    }
    
    public func setTitle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let title: String =  args["title"] as! String;

        ensureStatusItem()
        if title == lastTitle {
            result(true)
            return
        }
        lastTitle = title
        if let button = statusItem?.button {
            if let attributes = textAttributes {
                button.attributedTitle = NSAttributedString(string: title, attributes: attributes)
            } else {
                button.title = title
            }
        }
        updateImagePosition(for: title)
        
        result(true)
    }
    
    public func setContextMenu(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        
        trayMenu = TrayMenu(args["menu"] as! [String: Any])
        trayMenu?.onMenuItemClick = { [weak self] (menuItem: NSMenuItem) in
            guard let strongSelf = self else { return }
            let args: NSDictionary = [
                "id": menuItem.tag,
            ]
            strongSelf.channel.invokeMethod(kEventOnTrayMenuItemClick, arguments: args, result: nil)
        }
        trayMenu?.delegate = self
        
        result(true)
    }
    
    public func popUpContextMenu(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (trayMenu != nil) {
            statusItem?.menu = trayMenu
            statusItem?.button?.performClick(nil)
        }
        result(true)
    }
    
    // NSMenuDelegate
    
    public func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
    }
}
