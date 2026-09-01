//
//  AppUpdater.swift
//  Adel Intelligence
//
//  Created by Adel on 06/07/24.
//

import Combine
import Foundation
import Sparkle

@MainActor
@Observable
final class AppUpdater {
    private var cancellable: AnyCancellable?
    var canCheckForUpdates = false
    
    init(_ updater: SPUUpdater) {
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .sink { [weak self] value in
                Task { @MainActor [weak self] in
                    self?.canCheckForUpdates = value
                }
            }
    }
}
