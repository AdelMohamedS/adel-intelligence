//
//  SidebarListItemView.swift
//  Adel Intelligence
//
//  Created by Adel on 8/2/24.
//

import SwiftUI

struct SidebarListItemView: View {
    private let chatViewModel: ChatViewModel
    private let chat: Chat
    private let name: String
    private let message: String?
    
    init(chatViewModel: ChatViewModel, chat: Chat, name: String, message: String?) {
        self.chatViewModel = chatViewModel
        self.chat = chat
        self.name = name
        self.message = message
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(name)
                .font(.headline.weight(.semibold))
            
            if let message {
                Text(message)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityValue(message ?? "No messages")
        .accessibilityHint("Select this chat")
        .accessibilityAction(named: "Rename chat") {
            chatViewModel.selectedChats = [chat]
            chatViewModelBindable.isRenameChatPresented = true
        }
        .accessibilityAction(named: "Delete chat") {
            chatViewModel.selectedChats = [chat]
            chatViewModelBindable.isDeleteConfirmationPresented = true
        }
        .contextMenu {
            SidebarContextMenu(chatViewModel: chatViewModel)
        }
    }
}
