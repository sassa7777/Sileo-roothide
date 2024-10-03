//
//  DownloadPackage.swift
//  Sileo
//
//  Created by CoolStar on 8/2/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

final class DownloadPackage: Hashable {
    public var package: Package
    
    init(package: Package) {
        self.package = package
    }
    
    func hash(into hasher: inout Hasher) {
        //NSLog("SileoLog: DownloadPackage.hash \(package.package) \(package.version) \(package.package) \(package.sourceRepo?.url)")

        //shit, this is inconsistent with its custom operator== and may cause crash and incorrect result
        //hasher.combine(package)
        
        hasher.combine(package.package)
    }

}

func == (lhs: DownloadPackage, rhs: DownloadPackage) -> Bool {
    //NSLog("SileoLog: DownloadPackage \(lhs.package.package) == \(rhs.package.package):\(lhs.package.package == rhs.package.package)")
    //Thread.callStackSymbols.forEach{NSLog("SileoLog: DownloadPackage(==) callstack=\($0)")}

    return lhs.package.package == rhs.package.package
}
