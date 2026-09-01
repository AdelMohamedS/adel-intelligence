// ComparisonChatView.swift
//  Adel Intelligence
//
//  Created on 4/15/25.
//

import ChatField
import Defaults
import OllamaKit
import SwiftUI
import ViewCondition

struct ComparisonChatView: View {
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel

    @State private var ollamaKit: OllamaKit
    @State private var userPrompt: String = ""
    @State private var chatGPTResponse: String = ""
    @State private var copilotResponse: String = ""
    @State private var geminiResponse: String = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isPreferencesPresented: Bool = false

    // New states for chart functionality
    @State private var comparisonOutput: String = ""
    @State private var showChart: Bool = false

    init() {
        let baseURL = URL(string: Defaults[.defaultHost])!
        self._ollamaKit = State(initialValue: OllamaKit(baseURL: baseURL))
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack {
                List(messageViewModel.messages) { message in
                    let lastMessageId = messageViewModel.messages.last?.id

                    UserMessageView(
                        content: message.prompt,
                        copyAction: self.copyAction
                    )
                    .padding(.top)
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)

                    AssistantMessageView(
                        content: message.response ?? messageViewModel.tempResponse,
                        isGenerating: messageViewModel.loading == .generate,
                        isLastMessage: lastMessageId == message.id,
                        copyAction: self.copyAction,
                        regenerateAction: self.regenerateAction,
                        showChartsAction: {
                            print("Show Charts button clicked in ComparisonChatView!")
                            if let response = message.response {
                                print("Response exists with length: \(response.count)")
                                if let jsonOutput = extractJsonFromResponse(response) {
                                    print("JSON extracted successfully, setting chart data")
                                    comparisonOutput = jsonOutput
                                    showChart = true
                                } else {
                                    print("Failed to extract JSON from response")
                                }
                            } else {
                                print("No response available to extract JSON from")
                            }
                        }
                    )
                    .id(message)
                    .padding(.top)
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)
                    .if(lastMessageId == message.id) { view in
                        view.padding(.bottom)
                    }
                }

                VStack(spacing: 12) {
                    // User Prompt
                    VStack(alignment: .leading) {
                        Text("Enter Prompt")
                            .font(.headline)
                            .padding(.leading, 5)

                        TextEditor(text: $userPrompt)
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // ChatGPT Response
                    VStack(alignment: .leading) {
                        Text("Enter ChatGPT's Response")
                            .font(.headline)
                            .padding(.leading, 5)

                        TextEditor(text: $chatGPTResponse)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Microsoft Copilot Response
                    VStack(alignment: .leading) {
                        Text("Enter Microsoft Copilot's Response")
                            .font(.headline)
                            .padding(.leading, 5)

                        TextEditor(text: $copilotResponse)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Google Gemini Response
                    VStack(alignment: .leading) {
                        Text("Enter Google Gemini's Response")
                            .font(.headline)
                            .padding(.leading, 5)

                        TextEditor(text: $geminiResponse)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Comparison Output
                    if !comparisonOutput.isEmpty {
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Comparison Results")
                                    .font(.headline)
                                    .padding(.leading, 5)

                                Spacer()

                                Button(action: {
                                    showChart.toggle()
                                }) {
                                    Label(
                                        showChart ? "Hide Chart" : "Show Chart",
                                        systemImage: showChart ? "chart.bar.xaxis" : "chart.bar")
                                }
                                .buttonStyle(.borderless)
                            }

                            if showChart {
                                ComparisonChartView(jsonString: comparisonOutput)
                                    .frame(height: 400)
                                    .padding(.vertical)
                            } else {
                                TextEditor(text: $comparisonOutput)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color(.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    // Submit Button
                    HStack {
                        Button(action: submitComparison) {
                            Text("Submit Comparison")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(
                            userPrompt.isEmpty || chatGPTResponse.isEmpty || copilotResponse.isEmpty
                                || geminiResponse.isEmpty)

                        // Test chart button
                        Button(action: testChartWithSampleData) {
                            Text("Test Chart")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding()
                .visible(if: chatViewModel.activeChat.isNotNil, removeCompletely: true)
            }
            .onAppear {
                self.scrollProxy = proxy
            }
            .onChange(of: chatViewModel.activeChat?.id) {
                self.onActiveChatChanged()
            }
            .onChange(of: messageViewModel.tempResponse) {
                if let proxy = scrollProxy {
                    scrollToBottom(proxy: proxy)
                }
                // Check if there's JSON data in the response
                if let jsonOutput = extractJsonFromResponse(messageViewModel.tempResponse) {
                    comparisonOutput = jsonOutput
                    showChart = true
                }
            }
            .onChange(of: messageViewModel.messages.last?.response) { newResponse in
                // Also check completed responses for JSON
                if let response = newResponse, let jsonOutput = extractJsonFromResponse(response) {
                    comparisonOutput = jsonOutput
                    showChart = true
                }
            }
        }
        .navigationTitle(chatViewModel.activeChat?.name ?? "Adel Intelligence (AI)")
        .navigationSubtitle(chatViewModel.activeChat?.model ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Show Preferences", systemImage: "sidebar.trailing") {
                    isPreferencesPresented.toggle()
                }
            }
        }
        .inspector(isPresented: $isPreferencesPresented) {
            ChatPreferencesView(ollamaKit: $ollamaKit)
                .inspectorColumnWidth(min: 320, ideal: 320)
        }
    }

    private func onActiveChatChanged() {
        self.userPrompt = ""
        self.chatGPTResponse = ""
        self.copilotResponse = ""
        self.geminiResponse = ""
        self.comparisonOutput = ""  // Clear comparison output
        self.showChart = false  // Hide chart

        if let activeChat = chatViewModel.activeChat, let host = activeChat.host,
            let baseURL = URL(string: host)
        {
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

        // Format the combined message
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

        // Send the message using the existing system
        messageViewModel.generate(ollamaKit, activeChat: activeChat, prompt: formattedMessage)

        // Clear the input fields
        userPrompt = ""
        chatGPTResponse = ""
        copilotResponse = ""
        geminiResponse = ""
        comparisonOutput = ""  // Clear comparison output
        showChart = false  // Hide chart
    }

    private func regenerateAction() {
        guard let activeChat = chatViewModel.activeChat, !activeChat.model.isEmpty,
            chatViewModel.isHostReachable
        else { return }

        if messageViewModel.loading == .generate {
            messageViewModel.cancelGeneration()
        } else {
            guard let activeChat = chatViewModel.activeChat else { return }

            messageViewModel.regenerate(ollamaKit, activeChat: activeChat)
        }
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
        // Don't proceed with empty responses
        guard !response.isEmpty else {
            print("Response is empty")
            return nil
        }

        print("Attempting to extract JSON from response of length: \(response.count)")

        // Safer version: use a simplified approach to avoid regex issues
        do {
            // Try to find JSON code blocks first
            if response.contains("```json") {
                print("Found json code block marker")
                if let startIndex = response.range(of: "```json")?.upperBound,
                    let endIndex = response[startIndex...].range(of: "```")?.lowerBound
                {
                    let jsonContent = String(response[startIndex..<endIndex]).trimmingCharacters(
                        in: .whitespacesAndNewlines)
                    print("Extracted JSON from code block, length: \(jsonContent.count)")
                    return validateAndFormatJson(jsonString: jsonContent)
                }
            }

            // Look for raw JSON objects by finding matching braces
            if let startIndex = response.firstIndex(of: "{"),
                let lastIndex = response.lastIndex(of: "}")
            {
                if startIndex < lastIndex {
                    let potentialJson = String(response[startIndex...lastIndex])
                    print("Found potential raw JSON object, length: \(potentialJson.count)")
                    // Verify it contains our required fields
                    if potentialJson.contains("criteria") && potentialJson.contains("scores") {
                        return validateAndFormatJson(jsonString: potentialJson)
                    }
                }
            }

            print("No valid JSON pattern found")
            return nil
        } catch {
            print("Error while extracting JSON: \(error.localizedDescription)")
            return nil
        }
    }

    // Validate that the JSON contains necessary fields and is valid
    private func validateAndFormatJson(jsonString: String) -> String? {
        let trimmedJson = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedJson.isEmpty else {
            print("JSON string is empty after trimming")
            return nil
        }

        // Quick validation - must contain both criteria and scores
        guard trimmedJson.contains("criteria") && trimmedJson.contains("scores") else {
            print("JSON does not contain required fields (criteria and scores)")
            return nil
        }

        // Make sure it's a valid JSON object by parsing it
        guard let jsonData = trimmedJson.data(using: .utf8) else {
            print("Failed to convert JSON string to data")
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData)
            guard let dict = json as? [String: Any],
                dict["criteria"] != nil && dict["scores"] != nil
            else {
                print("JSON does not have valid criteria and scores fields")
                return nil
            }

            // Optionally, pretty-print the JSON
            let prettyData = try JSONSerialization.data(
                withJSONObject: json, options: .prettyPrinted)
            if let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }

            return trimmedJson
        } catch {
            print("JSON validation error: \(error.localizedDescription)")
            return nil
        }
    }

    // Add this function to test the chart with sample data
    private func testChartWithSampleData() {
        let sampleJson = """
            {
              "criteria": ["Accuracy", "Response Time", "Relevance", "User Satisfaction", "User Engagement"],
              "scores": {
                "ChatGPT": [8, 9, 9, 9, 9],
                "Microsoft Copilot": [7, 6, 6, 7, 6],
                "Google Gemini": [5, 8, 5, 5, 6]
              }
            }
            """

        comparisonOutput = sampleJson
        showChart = true
    }
}
