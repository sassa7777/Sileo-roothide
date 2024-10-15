//
//  URL+Secure.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

extension URL {
    var isSecure: Bool {
        self.isSecure(prefix: "")
    }
    
    func isSecure(prefix: String) -> Bool {
        if UserDefaults.standard.bool(forKey: "DeveloperMode") {
            return true
        }
        #if TARGET_SANDBOX || targetEnvironment(simulator)
        return prefix.isEmpty || self.scheme?.lowercased().hasPrefix(prefix) == true
        #else
        let expectedScheme = prefix.isEmpty ? "https" : String(format: "%@-https", prefix.lowercased())
        return expectedScheme == self.scheme?.lowercased()
        #endif
    }
    
    var aptContents: String? {
        if let handle = FileHandle(forReadingAtPath: self.path) {
            return String(decoding: handle.availableData, as: UTF8.self)
        }
        return nil
    }
    
    init?(string: String?) {
        guard let string else { return nil }
        self.init(string: string)
    }
}
