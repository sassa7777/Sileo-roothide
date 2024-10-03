//
//  SileoNavigationController.swift
//  Sileo
//
//  Created by CoolStar on 7/27/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class SileoNavigationController: UINavigationController {
    override var childForStatusBarStyle: UIViewController? {
        viewControllers.last
    }
    
    public var rootViewController: UIViewController?
    
    override public init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        self.rootViewController = rootViewController
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
