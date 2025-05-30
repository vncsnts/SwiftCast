//
//  FloatingViewModifier.swift
//  SwiftCast
//
//  Created by Vince Carlo Santos on 7/3/23.
//

import SwiftUI

/// A floating panel window for displaying SwiftUI content in a separate window.
class FloatingPanel<Content: View>: NSWindow {
    /// Binding to control the presentation state of the panel.
    @Binding var isPresented: Bool
    /// Initializes a new floating panel.
    /// - Parameters:
    ///   - view: The SwiftUI view to display.
    ///   - contentRect: The initial size and position of the panel.
    ///   - styleMask: The window style mask.
    ///   - backing: The window backing store type.
    ///   - flag: Whether to defer creation of the window.
    ///   - isPresented: Binding to the presentation state.
    init(view: () -> Content,
         contentRect: NSRect,
         styleMask: NSWindow.StyleMask = [.borderless, .fullSizeContentView],
         backing: NSWindow.BackingStoreType = .buffered,
         defer flag: Bool = false,
         isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        super.init(contentRect: contentRect,
                   styleMask: styleMask,
                   backing: backing,
                   defer: flag)
        self.title = "floating-view"
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.backgroundColor = .clear
        self.contentView = NSHostingView(rootView: view()
            .clipShape(Circle())
            .contentShape(Circle())
            .ignoresSafeArea()
            .environment(\.floatingPanel, self))
    }
    /// Closes the panel and updates the presentation state.
    override func close() {
        super.close()
        isPresented = false
    }
    /// Allows the panel to become the key window.
    override var canBecomeKey: Bool { true }
    /// Allows the panel to become the main window.
    override var canBecomeMain: Bool { true }
}

// MARK: - Environment Key
private struct FloatingPanelKey: EnvironmentKey {
    static let defaultValue: NSWindow? = nil
}

extension EnvironmentValues {
    /// The floating panel window in the environment.
    var floatingPanel: NSWindow? {
        get { self[FloatingPanelKey.self] }
        set { self[FloatingPanelKey.self] = newValue }
    }
}

/// A view modifier to present a floating panel in SwiftUI.
fileprivate struct FloatingPanelModifier<PanelContent: View>: ViewModifier {
    /// Determines whether the panel should be presented or not.
    @Binding var isPresented: Bool
    /// The initial size of the panel.
    var contentRect: CGRect = CGRect(x: 0, y: 0, width: 300, height: 300)
    /// The panel content's view closure.
    @ViewBuilder let view: () -> PanelContent
    /// Stores the panel instance.
    @State var panel: FloatingPanel<PanelContent>?
    func body(content: Content) -> some View {
        content
            .onAppear {
                /// When the view appears, create, center and present the panel if ordered
                panel = FloatingPanel(view: view, contentRect: contentRect, isPresented: $isPresented)
                panel?.center()
                if isPresented {
                    present()
                }
            }.onChange(of: isPresented) { value in
                /// On change of the presentation state, make the panel react accordingly
                if value {
                    present()
                } else {
                    unpresent()
                }
            }
    }
    /// Presents the panel and makes it the key window
    func present() {
        panel?.orderFront(nil)
        panel?.makeKey()
    }
    
    /// Unpresents the panel
    func unpresent() {
        panel?.orderOut(nil)
    }
}

extension View {
    /// Presents a floating panel in SwiftUI fashion
    /// - Parameters:
    ///   - isPresented: A boolean binding that keeps track of the panel's presentation state
    ///   - contentRect: The initial content frame of the window
    ///   - content: The displayed content
    func floatingPanel<Content: View>(isPresented: Binding<Bool>,
                                      contentRect: CGRect = CGRect(x: 0, y: 0, width: 300, height: 300),
                                      @ViewBuilder content: @escaping () -> Content) -> some View {
        self.modifier(FloatingPanelModifier(isPresented: isPresented, contentRect: contentRect, view: content))
    }
}
