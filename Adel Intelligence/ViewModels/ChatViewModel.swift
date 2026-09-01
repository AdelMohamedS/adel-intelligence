//
//  ChatViewModel.swift
//
//
//  Created by Adel on 13/07/24.
//

import Defaults
import OllamaKit
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    private var modelContext: ModelContext
    private var fetchModelsTask: Task<Void, Never>?
    private var fetchModelsRequestID = UUID()
    private var _chatNameTemp: String = ""
    
    var models: [String] = []
    
    var chats: [Chat] = []
    var activeChat: Chat? = nil
    var selectedChats = Set<Chat>()

    var shouldFocusPrompt = false

    var isHostReachable: Bool = true
    var loading: ChatViewModelLoading? = nil
    var error: ChatViewModelError? = nil
    
    var isRenameChatPresented = false
    var isDeleteConfirmationPresented = false
    
    var chatNameTemp: String {
        get {
            if isRenameChatPresented, let activeChat {
                return activeChat.name
            }
            
            return _chatNameTemp
        }
        
        set {
            _chatNameTemp = newValue
        }
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchModels(_ ollamaKit: OllamaKit) {
        fetchModelsTask?.cancel()
        let requestID = UUID()
        fetchModelsRequestID = requestID
        self.loading = .fetchModels
        self.error = nil
        
        fetchModelsTask = Task { [weak self] in
            guard let self else { return }

            do {
                defer {
                    guard self.fetchModelsRequestID == requestID else { return }
                    self.loading = nil
                    self.fetchModelsTask = nil
                }
                
                let isReachable = await ollamaKit.reachable()

                try Task.checkCancellation()
                guard self.fetchModelsRequestID == requestID else { return }
                
                guard isReachable else {
                    self.error = .fetchModels("Unable to connect to Ollama server. Please verify that Ollama is running and accessible.")
                    return
                }
                
                let response = try await ollamaKit.models()
                try Task.checkCancellation()
                guard self.fetchModelsRequestID == requestID else { return }
                self.models = response.models.map { $0.name }
                
                guard !self.models.isEmpty else {
                    self.error = .fetchModels("You don't have any Ollama model. Please pull at least one Ollama model first.")
                    return
                }
                
                if let host = activeChat?.host, host.isEmpty {
                    self.activeChat?.host = self.models.first
                }
            } catch is CancellationError {
                // Cancellation is expected when a newer request replaces this one.
            } catch {
                guard self.fetchModelsRequestID == requestID else { return }
                self.error = .fetchModels(error.localizedDescription)
            }
        }
    }
    
    func load() {
        do {
            let sortDescriptor = SortDescriptor(\Chat.modifiedAt, order: .reverse)
            let fetchDescriptor = FetchDescriptor<Chat>(sortBy: [sortDescriptor])
            
            self.chats = try self.modelContext.fetch(fetchDescriptor)
        } catch {
            self.error = .load(error.localizedDescription)
        }
    }
    
    func create(model: String) {
        let chat = Chat(model: model)
        self.modelContext.insert(chat)

        do {
            try self.modelContext.save()
        } catch {
            self.modelContext.delete(chat)
            self.error = .save(error.localizedDescription)
            return
        }
        
        self.chats.insert(chat, at: 0)
        self.selectedChats = [chat]
        self.shouldFocusPrompt = true
    }
    
    func rename() {
        guard let activeChat else { return }
        
        if let index = self.chats.firstIndex(where: { $0.id == activeChat.id }) {
            let previousName = self.chats[index].name
            let previousModifiedAt = self.chats[index].modifiedAt
            self.chats[index].name = _chatNameTemp
            self.chats[index].modifiedAt = .now

            do {
                try self.modelContext.save()
            } catch {
                self.chats[index].name = previousName
                self.chats[index].modifiedAt = previousModifiedAt
                self.error = .save(error.localizedDescription)
            }
        }
    }
    
    func remove() {
        for chat in selectedChats {
            self.modelContext.delete(chat)
        }

        do {
            try self.modelContext.save()
            self.chats.removeAll(where: { self.selectedChats.contains($0) })
            self.selectedChats.removeAll()
        } catch {
            self.error = .save(error.localizedDescription)
        }
    }
    
    func removeTemporaryChat(chatToRemove: Chat) {
        if (chatToRemove.name == Defaults[.defaultChatName] && chatToRemove.messages.isEmpty) {
            self.modelContext.delete(chatToRemove)

            do {
                try self.modelContext.save()
                self.chats.removeAll(where: { $0.id == chatToRemove.id })
            } catch {
                self.error = .save(error.localizedDescription)
            }
        }
    }
}

enum ChatViewModelLoading {
    case fetchModels
}

enum ChatViewModelError: Error {
    case fetchModels(String)
    case load(String)
    case save(String)
}
