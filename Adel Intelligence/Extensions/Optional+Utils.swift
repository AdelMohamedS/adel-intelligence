//
//  Optional+Utils.swift
//  Adel Intelligence
//
//  Created by Adel on 13/07/24.
//

import Foundation

extension Optional {
    var isNil: Bool {
        self == nil
    }
    
    var isNotNil: Bool {
        self != nil
    }
}
