////
////  File.swift
////  
////
////  Created by Amy While on 14/04/2023.
////
//
//import Foundation
//#if canImport(UIKit)
//import UIKit
//
//extension UIApplication {
//    
//    static func overrideLayout(rtl: Bool) {
//        let sel = NSSelectorFromString("_setForcedUserInterfaceLayoutDirection:")
//        guard UIApplication.shared.responds(to: sel) else {
//            return
//        }
//        let imp = UIApplication.shared.method(for: sel)
//        typealias _setForcedUserInterfaceLayoutDirection = @convention(c) (AnyObject, Selector, UIUserInterfaceLayoutDirection) -> Void
//        let swiftable = unsafeBitCast(imp, to: _setForcedUserInterfaceLayoutDirection.self)
//        swiftable(UIApplication.shared, sel, rtl ? .rightToLeft : .leftToRight)
//    }
//    
//}
//#endif
