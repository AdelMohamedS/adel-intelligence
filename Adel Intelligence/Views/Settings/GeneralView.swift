//
//  GeneralView.swift
//
//
//  Created by Adel on 13/07/24.
//

import Defaults
import SwiftUI

struct GeneralView: View {
    @Default(.defaultHost) private var defaultHost
    @Default(.defaultSystemPrompt) private var defaultSystemPrompt
    
    @State private var isUpdateOllamaHostPresented = false
    @State private var isUpdateSystemPromptPresented = false
    @AccessibilityFocusState private var hostChangeFocused: Bool
    @AccessibilityFocusState private var promptChangeFocused: Bool
    
    var body: some View {
        Form {
            Section {
                Box {
                    Text("Default Ollama Host")
                        .font(.headline.weight(.semibold))
                    
                    HStack {
                        Text(defaultHost)
                            .help(defaultHost)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateOllamaHostPresented = true })
                            .accessibilityFocused($hostChangeFocused)
                    }
                }
            } footer: {
                SectionFooter("This host will be used for new chats.")
                    .padding(.bottom)
            }
            
            Section {
                Box {
                    Text("Default System Prompt")
                        .font(.headline.weight(.semibold))
                    
                    HStack {
                        Text(defaultSystemPrompt)
                            .help(defaultSystemPrompt)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Change", action: { isUpdateSystemPromptPresented = true })
                            .accessibilityFocused($promptChangeFocused)
                    }
                }
            } footer: {
                SectionFooter("This prompt will be used for new chats.")
            }

            Section {
                Box {
                    DefaultFontSizeField()
                }
            }
        }
        .sheet(isPresented: $isUpdateOllamaHostPresented) {
            UpdateOllamaHostSheet(host: defaultHost) { host in
                self.defaultHost = host
            }
            .onDisappear { hostChangeFocused = true }
        }
        .sheet(isPresented: $isUpdateSystemPromptPresented) {
            UpdateSystemPromptSheet(prompt: defaultSystemPrompt) { prompt in
                self.defaultSystemPrompt = prompt
            }
            .onDisappear { promptChangeFocused = true }
        }
    }
}
