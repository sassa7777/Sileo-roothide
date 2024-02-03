//
//  Logging.swift
//  
//
//  Created by Amy While on 08/01/2022.
//

import Foundation

public func print(_ items: String..., filename: String = #fileID, function : String = #function, line: Int = #line, separator: String = " ", terminator: String = "\n") {
    let formatted = "\(filename) [#\(line) \(function)] ->\(separator)"
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(formatted + output, terminator: terminator)
}

public func print(_ items: Any..., filename: String = #fileID, function : String = #function, line: Int = #line, separator: String = " ", terminator: String = "\n") {
    let formatted = "\(filename) [#\(line) \(function)] ->\(separator)"
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(formatted + output, terminator: terminator)
}
