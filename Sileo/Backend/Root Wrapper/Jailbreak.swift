//
//  File.swift
//  Sileo
//
//  Created by Amy While on 15/04/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation
import MachO

enum Jailbreak: String, Codable {
    
    static let current = Jailbreak()
    static let bootstrap = Bootstrap(jailbreak: current)
    
    // Coolstar
    case electra = "Electra (iOS 11)"
    case chimera = "Chimera (iOS 12)"
    case odyssey = "Odyssey (iOS 13)"
    case taurine = "Taurine (iOS 14)"
    
    // unc0ver
    case unc0ver11 = "unc0ver (iOS 11)"
    case unc0ver12 = "unc0ver (iOS 12)"
    case unc0ver13 = "unc0ver (iOS 13)"
    case unc0ver14 = "unc0ver (iOS 14)"
    
    // checkra1n
    case checkra1n12 = "checkra1n (iOS 12)"
    case checkra1n13 = "checkra1n (iOS 13)"
    case checkra1n14 = "checkra1n (iOS 14)"
    
    // Odysseyra1n
    case odysseyra1n12 = "Odysseyra1n (iOS 12)"
    case odysseyra1n13 = "Odysseyra1n (iOS 13)"
    case odysseyra1n14 = "Odysseyra1n (iOS 14)"
    
    // Palera1n
    case palera1n_rootless15 = "palera1n Rootless (iOS 15)"
    case palera1n_rootless16 = "palera1n Rootless (iOS 16)"
    case palera1n_rootful15 = "palera1n Rootful (iOS 15)"
    case palera1n_rootful16 = "palera1n Rootful (iOS 16)"
    case palera1n17 = "palera1n (iPadOS 17)"
    
    // Xina
    case xina15 = "XinaA15 (iOS 15)"
    
    // Fugu15
    case fugu15 = "Fugu15 (iOS 15)"
    case dopamine = "Dopamine-roothide (iOS 15)"
    
    // Bakera1n
    case bakera1n_rootless15 = "bakera1n Rootless (iOS 15)"
    case bakera1n_rootless16 = "bakera1n Rootless (iOS 16)"
    case bakera1n_rootful15 = "bakera1n Rootful (iOS 15)"
    case bakera1n_rootful16 = "bakera1n Rootful (iOS 16)"
    case bakera1n17 = "bakera1n (iPadOS 17)"
    
    case mac = "macOS"
    case other = "Other"
    case simulator = "Simulator"
    
    case BOOTSTRAP14 = "Bootstrap (iOS 14)"
    case BOOTSTRAP15 = "Bootstrap (iOS 15)"
    case BOOTSTRAP16 = "Bootstrap (iOS 16)"
    case BOOTSTRAP17 = "Bootstrap (iOS 17)"
    
    
    fileprivate static func arch() -> String {
        guard let archRaw = NXGetLocalArchInfo().pointee.name else {
            return "arm64"
        }
        return String(cString: archRaw)
    }
    
    static private let supported: Set<Jailbreak> = [.chimera, .odyssey, .taurine, .odysseyra1n12, .odysseyra1n13, .odysseyra1n14, .palera1n_rootful15, .palera1n_rootful16, .palera1n_rootless15, .palera1n_rootless16, .palera1n17, .fugu15, .dopamine]
    public var supportsUserspaceReboot: Bool {
        Self.supported.contains(self)
    }
    
    private init() {
        #if targetEnvironment(simulator)
        self = .simulator
        return
        #endif
        
        #if targetEnvironment(macCatalyst)
        self = .mac
        return
        #endif
        
        
        let dopamine = URL(fileURLWithPath: jbroot("/.installed_dopamine"))
        if dopamine.exists {
            self = .dopamine
            return
        } else if #available(iOS 17.0.1, *) {
            self = .other
            return
        } else if #available(iOS 17.0, *) {
            self = .BOOTSTRAP17
            return
        } else if #available(iOS 16.0, *) {
            self = .BOOTSTRAP16
            return
        } else if #available(iOS 15.0, *) {
            self = .BOOTSTRAP15
            return
        } else if #available(iOS 14.0, *) {
            self = .BOOTSTRAP14
            return
        }
        
        self = .other
        
    }

    
}
