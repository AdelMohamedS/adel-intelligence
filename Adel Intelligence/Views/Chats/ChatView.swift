//
//  ChatView.swift
//  Adel Intelligence
//
//  Created by Adel on 8/2/24.
//

import Defaults
import ChatField
import OllamaKit
import SwiftUI
import ViewCondition

struct ChartData: Identifiable {
    let id = UUID()
    let jsonString: String
}

struct ChatView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(CodeHighlighter.self) private var codeHighlighter
    @Environment(FocusManager.self) private var focusManager
    
    @AppStorage("experimentalCodeHighlighting") private var experimentalCodeHighlighting = false
    @Default(.fontSize) private var fontSize
    
    @State private var ollamaKit: OllamaKit
    @State private var prompt: String = ""
    @State private var userPrompt: String = ""
    @State private var chatGPTResponse: String = ""
    @State private var copilotResponse: String = ""
    @State private var geminiResponse: String = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isPreferencesPresented: Bool = false
    @FocusState private var isFocused: Bool
    @State private var isComparisonMode: Bool = false
    @State private var isChartModalPresented: Bool = false
    @State private var chartJsonData: String = ""
    @State private var chartDataToPresent: ChartData? = nil
    
    init() {
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }
    
    private var messagesList: some View {
        List {
            Section {
                ForEach(messageViewModel.messages) { message in
                    let lastMessageId = messageViewModel.messages.last?.id
                    
                    // User bubble
                    UserMessageView(
                        content: message.prompt,
                        copyAction: self.copyAction
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 12))
                    
                    // Assistant bubble
                    AssistantMessageView(
                        content: message.response ?? messageViewModel.tempResponse,
                        isGenerating: messageViewModel.loading == .generate,
                        isLastMessage: lastMessageId == message.id,
                        copyAction: self.copyAction,
                        regenerateAction: self.regenerateAction,
                        showChartsAction: { self.showChartsAction(for: message) }
                    )
                    .id(message)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .if(lastMessageId == message.id) { view in
                        view.padding(.bottom, 8)
                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollIndicators(.visible)
    }

    var body: some View {
        ScrollViewReader { proxy in
            mainContent(proxy: proxy)
                .navigationTitle(chatViewModel.activeChat?.name ?? "Adel Intelligence (AI)")
                .navigationSubtitle(chatViewModel.activeChat?.model ?? "")
                .toolbar { toolbarContent }
                .inspector(isPresented: $isPreferencesPresented) {
                    ChatPreferencesView(ollamaKit: $ollamaKit)
                        .inspectorColumnWidth(min: 320, ideal: 360)
                }
                .sheet(item: $chartDataToPresent) { chartData in
                    ChartModal(jsonData: chartData.jsonString) {
                        chartDataToPresent = nil
                    }
                }
        }
    }
    
    private func mainContent(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            messagesList
            
            Divider()
                .padding(.top, 4)
            
            if isComparisonMode {
                comparisonInputSection
            } else {
                chatInputSection
            }
        }
        .onAppear { self.scrollProxy = proxy }
        .onChange(of: chatViewModel.activeChat?.id, initial: true) {
            self.onActiveChatChanged()
        }
        .onChange(of: messageViewModel.tempResponse) {
            if let proxy = scrollProxy {
                scrollToBottom(proxy: proxy)
            }
        }
        .onChange(of: colorScheme, initial: true) {
            codeHighlighter.colorScheme = colorScheme
        }
        .onChange(of: fontSize, initial: true) {
            codeHighlighter.fontSize = fontSize
        }
        .onChange(of: experimentalCodeHighlighting) {
            codeHighlighter.enabled = experimentalCodeHighlighting
        }
        .onChange(of: focusManager.shouldToggleInspector) { _, shouldToggle in
            if shouldToggle {
                isPreferencesPresented.toggle()
                focusManager.shouldToggleInspector = false
            }
        }
        .onChange(of: focusManager.shouldFocusTextField) { _, shouldFocus in
            if shouldFocus {
                isFocused = true
                focusManager.shouldFocusTextField = false
            }
        }
    }
    
    private var chatInputSection: some View {
        VStack(spacing: 8) {
            ChatField("Write your message here", text: $prompt) {
                if messageViewModel.loading != .generate {
                    generateAction()
                }
            } trailingAccessory: {
                Button {
                    generateAction()
                } label: {
                    Image(systemName: messageViewModel.loading == .generate ? "stop.fill" : "paperplane.fill")
                        .symbolVariant(.fill)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .help(messageViewModel.loading == .generate ? "Stop generating" : "Send")
                .disabled(prompt.isEmpty && messageViewModel.loading != .generate)
            } footer: {
                chatFieldFooter
            }
            .chatFieldStyle(.capsule)
            .focused($isFocused)
            .font(.system(size: fontSize))
            .onChange(of: isFocused) { _, newValue in
                focusManager.isTextFieldFocused = newValue
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .visible(if: chatViewModel.activeChat.isNotNil, removeCompletely: true)
    }
    
    private var comparisonInputSection: some View {
        VStack(spacing: 8) {
            ComparisonInputView(
                userPrompt: $userPrompt,
                chatGPTResponse: $chatGPTResponse,
                copilotResponse: $copilotResponse,
                geminiResponse: $geminiResponse,
                onSubmit: submitComparison
            )
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .visible(if: chatViewModel.activeChat.isNotNil, removeCompletely: true)
    }

    @ViewBuilder
    private var chatFieldFooter: some View {
        if chatViewModel.loading != nil {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Working…").foregroundStyle(.secondary)
            }
            .font(.callout)
        } else if case .fetchModels(let message) = chatViewModel.error {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message).foregroundStyle(.red)
                
                Button("Try Again", action: onActiveChatChanged)
                    .buttonStyle(.link)
            }
            .font(.callout)
        } else if messageViewModel.messages.isEmpty == false {
            ChatFieldFooterView("⌘R to regenerate the response")
                .foregroundColor(.secondary)
        } else {
            ChatFieldFooterView("AI can make mistakes. Please double-check responses.")
                .foregroundColor(.secondary)
        }
    }
    
    private func onActiveChatChanged() {
        self.prompt = ""
        self.userPrompt = ""
        self.chatGPTResponse = ""
        self.copilotResponse = ""
        self.geminiResponse = ""
        if chatViewModel.shouldFocusPrompt {
            chatViewModel.shouldFocusPrompt = false
            Task {
                try await Task.sleep(for: .seconds(0.8))
                withAnimation {
                    self.isFocused = true
                }
            }
        }
        
        if let activeChat = chatViewModel.activeChat, let host = activeChat.host, let baseURL = URL(string: host) {
            self.ollamaKit = OllamaKit(baseURL: baseURL)
            self.chatViewModel.fetchModels(self.ollamaKit)
        }
    }
        
    private func copyAction(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }
        
    private func submitComparison() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty,
              chatViewModel.isHostReachable
        else { return }
        
        let formattedMessage = """
        Prompt: "\(userPrompt)"
        
        ChatGPT's response
        {{{
            \(chatGPTResponse)
        }}}
        
        Microsoft Copilot's response
        {{{
            \(copilotResponse)
        }}}
        
        Google Gemini's response
        {{{
            \(geminiResponse)
        }}}
        """
        
        messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: formattedMessage)
        
        userPrompt = ""
        chatGPTResponse = ""
        copilotResponse = ""
        geminiResponse = ""
    }
        
    private func generateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else {
                self.prompt = ""
                return
            }
            guard let activeChat = chatViewModel.activeChat else { return }
            messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: prompt)
        }
        self.prompt = ""
    }
        
    private func regenerateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty, chatViewModel.isHostReachable else { return }
        
        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard let activeChat = chatViewModel.activeChat else { return }
            messageViewModel.regenerate(ollamaKit, activeChat: activeChat)
        }
        prompt = ""
    }
        
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard messageViewModel.messages.count > 0 else { return }
        guard let lastMessage = messageViewModel.messages.last else { return }
        
        DispatchQueue.main.async {
            proxy.scrollTo(lastMessage, anchor: .bottom)
        }
    }
        
    // Fixed function to parse and extract JSON from Ollama's response
    private func extractJsonFromResponse(_ response: String) -> String? {
        guard !response.isEmpty else { return nil }
        
        if response.contains("```json") {
            if let startIndex = response.range(of: "```json")?.upperBound,
               let endIndex = response[startIndex...].range(of: "```")?.lowerBound {
                let jsonContent = String(response[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                return validateAndFormatJson(jsonString: jsonContent)
            }
        }
        
        if let startIndex = response.firstIndex(of: "{"),
           let lastIndex = response.lastIndex(of: "}") {
            if startIndex < lastIndex {
                let potentialJson = String(response[startIndex...lastIndex])
                if potentialJson.contains("criteria") && potentialJson.contains("scores") {
                    return validateAndFormatJson(jsonString: potentialJson)
                }
            }
        }
        return nil
    }
        
    // Validate that the JSON contains necessary fields and is valid
    private func validateAndFormatJson(jsonString: String) -> String? {
        let trimmedJson = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedJson.isEmpty else { return nil }
        guard trimmedJson.contains("criteria") && trimmedJson.contains("scores") else { return nil }
        guard let jsonData = trimmedJson.data(using: .utf8) else { return nil }
            
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData)
            guard let dict = json as? [String: Any],
                  dict["criteria"] != nil && dict["scores"] != nil
            else { return nil }
                
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            if let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
            return trimmedJson
        } catch {
            return nil
        }
    }
        
    // Function to handle showing charts from the chat view
    private func handleShowCharts(jsonOutput: String) {
        chartDataToPresent = ChartData(jsonString: jsonOutput)
    }
    
    private func showChartsAction(for message: Message) {
        if let response = message.response,
           let jsonOutput = extractJsonFromResponse(response) {
            handleShowCharts(jsonOutput: jsonOutput)
        }
    }
    
    struct ComparisonInputView: View {
        @Binding var userPrompt: String
        @Binding var chatGPTResponse: String
        @Binding var copilotResponse: String
        @Binding var geminiResponse: String
        var onSubmit: () -> Void
        
        var body: some View {
            VStack(spacing: 12) {
                Group {
                    LabeledEditor(title: "Enter Prompt", text: $userPrompt, minHeight: 60)
                    LabeledEditor(title: "Enter ChatGPT's Response", text: $chatGPTResponse, minHeight: 100)
                    LabeledEditor(title: "Enter Microsoft Copilot's Response", text: $copilotResponse, minHeight: 100)
                    LabeledEditor(title: "Enter Google Gemini's Response", text: $geminiResponse, minHeight: 100)
                }
                
                Button(action: onSubmit) {
                    Label("Submit Comparison", systemImage: "paperplane.fill")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(userPrompt.isEmpty || chatGPTResponse.isEmpty || copilotResponse.isEmpty || geminiResponse.isEmpty)
            }
            .padding(.vertical, 8)
        }
        
        private struct LabeledEditor: View {
            let title: String
            @Binding var text: String
            var minHeight: CGFloat
            
            var body: some View {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    TextEditor(text: $text)
                        .frame(minHeight: minHeight)
                        .padding(8)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    struct ChartModal: View {
        var jsonData: String
        var onClose: () -> Void
        @State private var localJsonData: String
        
        init(jsonData: String, onClose: @escaping () -> Void) {
            self.jsonData = jsonData
            self.onClose = onClose
            self._localJsonData = State(initialValue: jsonData)
        }
        
        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    Text("Comparison Charts")
                        .font(.headline)
                    Spacer()
                    Button(role: .cancel, action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                Divider()
                
                if !localJsonData.isEmpty {
                    ComparisonChartView(jsonString: localJsonData)
                        .padding(.top, 8)
                } else {
                    VStack {
                        Text("No chart data available")
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    }
                }
            }
            .frame(minWidth: 640, idealWidth: 720, minHeight: 520, idealHeight: 600)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Picker("Mode", selection: $isComparisonMode) {
                Text("Chat").tag(false)
                Text("Compare").tag(true)
            }
            .pickerStyle(.segmented)
            .help("Switch between chat and comparison mode")
            .frame(width: 220)
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button {
                isPreferencesPresented.toggle()
            } label: {
                Label("Preferences", systemImage: "sidebar.trailing")
            }
            .help("Show Preferences")
        }
    }
}
