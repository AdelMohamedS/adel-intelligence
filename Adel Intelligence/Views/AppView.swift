//
//  AppView.swift
//  Adel Intelligence
//
//  Created by Adel on 03/11/23.
//

import SwiftUI
import Defaults
import AppKit

@MainActor
@Observable
final class FocusManager {
    var isTextFieldFocused: Bool = false
    var shouldToggleInspector: Bool = false
    var shouldFocusTextField: Bool = false
}

class TouchBarDelegate: NSObject, NSTouchBarDelegate {
    var newChatAction: (() -> Void)?
    var toggleSidebarAction: (() -> Void)?
    var toggleRightSidebarAction: (() -> Void)?
    var focusTextFieldAction: (() -> Void)?
    
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .newChatItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "", target: self, action: #selector(newChatPressed))
            button.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "New Chat")
            item.view = button
            return item
        case .toggleSidebarItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "", target: self, action: #selector(toggleSidebarPressed))
            button.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar")
            item.view = button
            return item
        case .toggleRightSidebarItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "", target: self, action: #selector(toggleRightSidebarPressed))
            button.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Toggle Right Sidebar")
            item.view = button
            return item
        case .focusTextFieldItem:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(title: "Write your message here", target: self, action: #selector(focusTextFieldPressed))
            button.bezelStyle = .rounded
            item.view = button
            return item
        case .flexibleSpaceLeft, .flexibleSpaceRight:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let view = NSView()
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            item.view = view
            return item
        default:
            return nil
        }
    }
    
    @objc func newChatPressed() {
        newChatAction?()
    }
    
    @objc func toggleSidebarPressed() {
        toggleSidebarAction?()
    }
    
    @objc func toggleRightSidebarPressed() {
        toggleRightSidebarAction?()
    }
    
    @objc func focusTextFieldPressed() {
        focusTextFieldAction?()
    }
}

extension NSTouchBarItem.Identifier {
    static let newChatItem = NSTouchBarItem.Identifier("com.adelintelligence.newchat")
    static let toggleSidebarItem = NSTouchBarItem.Identifier("com.adelintelligence.togglesidebar")
    static let toggleRightSidebarItem = NSTouchBarItem.Identifier("com.adelintelligence.togglerightsidebar")
    static let focusTextFieldItem = NSTouchBarItem.Identifier("com.adelintelligence.focustextfield")
    static let focusTextFieldGroup = NSTouchBarItem.Identifier("com.adelintelligence.focustextfieldgroup")
    static let flexibleSpaceLeft = NSTouchBarItem.Identifier("com.adelintelligence.flexiblespace.left")
    static let flexibleSpaceRight = NSTouchBarItem.Identifier("com.adelintelligence.flexiblespace.right")
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            self.callback(nsView?.window)
        }
    }
}

struct AppView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @State private var focusManager = FocusManager()
    @State private var touchBarDelegate = TouchBarDelegate()
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 256, ideal: 256)
        } detail: {
            ChatView()
        }
        .background(WindowAccessor { window in
            setupTouchBar(window: window)
        })
        .environment(focusManager)
        .onChange(of: chatViewModel.selectedChats) { oldSelectedChats, selectedChats in
            if selectedChats.count > 1 {
                chatViewModel.activeChat = nil
                messageViewModel.messages = []
            } else {
                guard let oldActiveChat = oldSelectedChats.first else { return }
                chatViewModel.removeTemporaryChat(chatToRemove: oldActiveChat)
                
                let selectedChatsArray = Array(selectedChats)
                guard let activeChat = selectedChatsArray.first else { return }
                
                chatViewModel.activeChat = activeChat
                messageViewModel.load(of: activeChat)
            }
        }
        .onChange(of: focusManager.isTextFieldFocused) { _, isFocused in
            updateTouchBarVisibility(isFocused: isFocused)
        }
    }
    
    private func setupTouchBar(window: NSWindow?) {
        let touchBar = NSTouchBar()
        touchBar.delegate = touchBarDelegate
        touchBar.defaultItemIdentifiers = [.toggleSidebarItem, .newChatItem, .flexibleSpaceLeft, .focusTextFieldItem, .flexibleSpaceRight, .toggleRightSidebarItem]
        
        touchBarDelegate.newChatAction = {
            print("TouchBar New Chat action triggered")
            chatViewModel.create(model: Defaults[.defaultModel])
        }
        
        touchBarDelegate.toggleSidebarAction = {
            print("TouchBar Toggle Sidebar action triggered")
            // Use the standard sidebar toggle command
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        }
        
        touchBarDelegate.toggleRightSidebarAction = {
            print("TouchBar Toggle Right Sidebar action triggered")
            // Toggle the inspector using our shared state
            focusManager.shouldToggleInspector.toggle()
        }
        
        touchBarDelegate.focusTextFieldAction = {
            print("TouchBar Focus Text Field action triggered")
            // Focus the text field using our shared state
            focusManager.shouldFocusTextField.toggle()
        }
        
        window?.touchBar = touchBar
    }
    
    private func updateTouchBarVisibility(isFocused: Bool) {
        guard let window = NSApplication.shared.windows.first else { return }
        
        if isFocused {
            window.touchBar?.defaultItemIdentifiers = []
        } else {
            window.touchBar?.defaultItemIdentifiers = [.toggleSidebarItem, .newChatItem, .flexibleSpaceLeft, .focusTextFieldItem, .flexibleSpaceRight, .toggleRightSidebarItem]
        }
    }
}
