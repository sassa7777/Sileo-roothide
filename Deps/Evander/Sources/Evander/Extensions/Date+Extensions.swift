//
//  File.swift
//  
//
//  Created by Amy While on 14/04/2023.
//

import Foundation

extension Date {
    
    init(timespec: timespec) {
        self.init(timeIntervalSince1970: Double(timespec.tv_sec) + Double(timespec.tv_nsec) / 1E9)
    }
    
}
