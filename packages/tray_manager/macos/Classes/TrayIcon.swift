import AppKit
//
//  TrayIcon.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/15.
//

// 自绘文本,替代 NSTextField。后者的 appearance 绘制会在 NSStatusItem replicant
// 重绘时反复触发 setNeedsDisplay,形成自激励循环(多屏 + 独立空间下 CPU 常驻高占用)。
class SpeedTextView: NSView {
    var attributedString: NSAttributedString? {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 42, height: NSView.noIntrinsicMetric)
    }

    override func draw(_ dirtyRect: NSRect) {
        attributedString?.draw(in: bounds)
    }
}

public class TrayIcon: NSView {
    public var onTrayIconMouseDown:(() -> Void)?
    public var onTrayIconMouseUp:(() -> Void)?
    public var onTrayIconRightMouseDown:(() -> Void)?
    public var onTrayIconRightMouseUp:(() -> Void)?

    var statusItem: NSStatusItem?

    var textAttributes: [NSAttributedString.Key : Any]?

    private let imageView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyDown
        iv.isHidden = true
        iv.setContentHuggingPriority(.required, for: .horizontal)
        return iv
    }()

    private let textView: SpeedTextView = {
        let v = SpeedTextView()
        v.isHidden = true
        return v
    }()

    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.distribution = .equalSpacing
        return stack
    }()


    public init() {
        super.init(frame: NSRect.zero)
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
            button.addSubview(self)
            self.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                self.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                self.topAnchor.constraint(equalTo: button.topAnchor),
                self.bottomAnchor.constraint(equalTo: button.bottomAnchor),
                self.heightAnchor.constraint(equalToConstant: NSStatusBar.system.thickness),
            ])
            setupView()
        }
    }

    private func setupView() {
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor,constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor,constant: -8),
            stackView.topAnchor.constraint(equalTo: topAnchor,constant:2),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor,constant:-2),
        ])

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.widthAnchor.constraint(equalToConstant: 42),
            textView.trailingAnchor.constraint(equalTo:stackView.trailingAnchor),
        ])
    }


    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect);
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setImage(_ image: NSImage, _ imagePosition: String) {
        let wasHidden = imageView.isHidden
        imageView.image = image
        imageView.isHidden = false
        // 仅显隐切换时 resize;图标尺寸一致,内容变化不改变宽度。
        if wasHidden != imageView.isHidden, let button = statusItem?.button {
            button.sizeToFit()
        }
    }

    public func setImagePosition(_ imagePosition: String) {
        self.frame = statusItem!.button!.frame
    }

    public func removeImage() {
        imageView.image = nil
        imageView.isHidden = true
        self.frame = statusItem!.button!.frame
    }

    public func setTitle(_ title: String) {
        let wasHidden = textView.isHidden
        textView.attributedString = title.isEmpty
            ? nil
            : NSAttributedString(string: title, attributes: textAttributes)
        textView.isHidden = title.isEmpty
        // 仅显隐切换时 resize;文本宽度固定(42),每秒更新不触发 geometry 变化。
        if wasHidden != textView.isHidden, let button = statusItem?.button {
            button.sizeToFit()
        }
    }

    public func setToolTip(_ toolTip: String) {
        if let button = statusItem?.button {
            button.toolTip  = toolTip
        }
    }

    public override func mouseDown(with event: NSEvent) {
        statusItem?.button?.highlight(true)
        self.onTrayIconMouseDown!()
    }

    public override func mouseUp(with event: NSEvent) {
        statusItem?.button?.highlight(false)
        self.onTrayIconMouseUp!()
    }

    public override func rightMouseDown(with event: NSEvent) {
        self.onTrayIconRightMouseDown!()
    }

    public override func rightMouseUp(with event: NSEvent) {
        self.onTrayIconRightMouseUp!()
    }
}
