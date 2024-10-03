//
//  UIPasteboard+Sources.swift
//  Sileo
//
//  Created by CoolStar on 8/4/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

extension UIPasteboard {
    func newSources() -> [String] {
        
        guard let string = self.string?.trimmingCharacters(in: .whitespaces),
              string.count > 0 else {
            return []
        }

        return string.components(separatedBy: .newlines).filter { $0.isEmpty == false }.filter {
            let parts = $0.components(separatedBy: .whitespaces)
            
            guard parts.count==1 || parts.count>=3 else {
                return false
            }
            
            guard let url = URL(string: parts[0]) else { return false }
            
            let suite = (parts.count > 1) ? parts[1] : "./"
            let components = (parts.count > 2) ? Array(parts[2...]) : nil
            
            guard ["http","https"].contains(url.scheme?.lowercased()) && url.host != nil else {
                return false
            }
            
            return !RepoManager.shared.hasRepo(with: url, suite: suite, components: components)
        }
    }
}
