//
//  String+RemoveTrailingSlash.swift
//
//
//  Created by Adel on 13/07/24.
//

import Foundation

extension String {
    func removeTrailingSlash() -> String {
        return self.hasSuffix("/") ? String(self.dropLast()) : self
    }
}
