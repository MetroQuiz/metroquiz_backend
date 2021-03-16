//
//  File.swift
//  
//
//  Created by Ivan Podvorniy on 16.03.2021.
//

import Foundation

extension NSRegularExpression {
    func matches(_ string: String) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return firstMatch(in: string, options: [], range: range) != nil
    }
}
