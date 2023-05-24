#if os(macOS)
import SwiftUI
import AppKit

public protocol WindowBackgroundStyle {
    associatedtype Body : View
    @ViewBuilder @MainActor var backgroud: Self.Body { get }
}

extension WindowBackgroundStyle where Self == TranslucentBackgroundStyle {
    public static var hiddenTitleBar: TranslucentBackgroundStyle { TranslucentBackgroundStyle() }
}

public struct TranslucentBackgroundStyle: WindowBackgroundStyle {
    public var backgroud: some View {
        TranslucentWindowBackground()
    }
}

extension View {
    @MainActor public func presentedWindowBackgroundStyle<S>(_ style: S) -> some View where S : WindowBackgroundStyle {
        self.background(style.backgroud)
    }
}

struct TranslucentWindowBackground: NSViewRepresentable {
    enum ContentViewConfiguration {
        case embed(NSView?)
        case replace(NSView?)
    }
    
    enum StyleMaskConfiguration {
        case insert(NSWindow.StyleMask)
        case replace(NSWindow.StyleMask)
    }
    
    struct WindowConfiguration {
        let isOpaque: Bool
        let backgroundColor: NSColor
        let contentViewCofiguration: ContentViewConfiguration
        let styleMaskConfiguration: StyleMaskConfiguration
        let titlebarAppearsTransparent: Bool
        let titleVisibility: NSWindow.TitleVisibility
        let standardWindowButtonConfig: StandardWindowButtonConfiguration
        let isMovableByWindowBackground: Bool
        
        public struct StandardWindowButtonConfiguration {
            let miniaturizeButtonIsHidden: Bool
            let closeButtonIsHidden: Bool
            let zoomButtonIsHidden: Bool
        }
        
        static func getTranlucentBackground() -> NSView {
            let visualEffect = NSVisualEffectView()
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .followsWindowActiveState
            visualEffect.material = .sidebar
            return visualEffect
        }
        
        static let translucent: WindowConfiguration = WindowConfiguration(
            isOpaque: false,
            backgroundColor: NSColor.clear,
            contentViewCofiguration: .embed(getTranlucentBackground()),
            styleMaskConfiguration: .insert(.titled),
            titlebarAppearsTransparent: true,
            titleVisibility: .visible,
            standardWindowButtonConfig: StandardWindowButtonConfiguration(
                miniaturizeButtonIsHidden: false,
                closeButtonIsHidden: false,
                zoomButtonIsHidden: false
            ),
            isMovableByWindowBackground: true
        )
        
        static func configure(window: NSWindow, forConfig config: WindowConfiguration) {
            
            window.isOpaque = config.isOpaque
            window.backgroundColor = config.backgroundColor
            
            switch config.contentViewCofiguration {
            case let .replace(view):
                window.contentView = view
            case let .embed(view):
                let currentContentView = window.contentView
                window.contentView = view
                if let currentContentView = currentContentView {
                    view?.addSubview(currentContentView)
                }
            }
            
            switch config.styleMaskConfiguration {
            case let .replace(mask):
                window.styleMask = mask
            case let .insert(mask):
                window.styleMask.insert(mask)
            }
            
            window.titlebarAppearsTransparent = config.titlebarAppearsTransparent
            window.titleVisibility = config.titleVisibility
            window.standardWindowButton(.miniaturizeButton)?.isHidden = config.standardWindowButtonConfig.miniaturizeButtonIsHidden
            window.standardWindowButton(.closeButton)?.isHidden = config.standardWindowButtonConfig.closeButtonIsHidden
            window.standardWindowButton(.zoomButton)?.isHidden = config.standardWindowButtonConfig.zoomButtonIsHidden
            window.isMovableByWindowBackground = config.isMovableByWindowBackground
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        private var _originalWindowConfiguration: WindowConfiguration?
        
        func createWindowConfigurationForCurrentContext(_ context: NSWindow) -> WindowConfiguration {
            WindowConfiguration(
                isOpaque: context.isOpaque,
                backgroundColor: context.backgroundColor,
                contentViewCofiguration: .replace(context.contentView),
                styleMaskConfiguration: .replace(context.styleMask),
                titlebarAppearsTransparent: context.titlebarAppearsTransparent,
                titleVisibility: context.titleVisibility,
                standardWindowButtonConfig: WindowConfiguration.StandardWindowButtonConfiguration(
                    miniaturizeButtonIsHidden: context.standardWindowButton(.miniaturizeButton)?.isHidden ?? false,
                    closeButtonIsHidden: context.standardWindowButton(.closeButton)?.isHidden ?? false,
                    zoomButtonIsHidden: context.standardWindowButton(.zoomButton)?.isHidden ?? false
                ),
                isMovableByWindowBackground: context.isMovableByWindowBackground
            )
        }
        
        func makeWindowTranslucent(window: NSWindow?) {
            guard let window = window else { return }
            self._originalWindowConfiguration = createWindowConfigurationForCurrentContext(window)
            let translucentWindowConfiguration = WindowConfiguration.translucent
            WindowConfiguration.configure(window: window, forConfig: translucentWindowConfiguration)
        }
        
        func resetWindow(window: NSWindow) {
            if let originalWindowConfiguration = _originalWindowConfiguration {
                WindowConfiguration.configure(window: window, forConfig: originalWindowConfiguration)
            }
        }
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            let window = view.window
            context.coordinator.makeWindowTranslucent(window: window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        guard let window = nsView.window else {
            return
        }
        coordinator.resetWindow(window: window)
    }
}
#endif
