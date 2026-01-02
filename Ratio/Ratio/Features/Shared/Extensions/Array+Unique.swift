//
//  Array+Unique.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import Foundation

extension Array where Element == String {
    func unique() -> [String] {
        Array(Set(self))
    }
}
