//
//  TabBarController.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import LNPopupController

class TabBarController: UITabBarController, UITabBarControllerDelegate {
    static var singleton: TabBarController?
    private var downloadsController: UINavigationController?
    private(set) public var popupIsPresented = false
    private var popupLock = DispatchSemaphore(value: 1)
    private var shouldSelectIndex = -1
    private var fuckedUpSources = false
//    private let ipadModeMinWidth = CGFloat(752) //debug
    private let ipadModeMinWidth = CGFloat(768)
    
    private var popupQueueLock = DispatchSemaphore(value: 1)
    private static let popupQueueContext = 50
    private static let popupQueueKey = DispatchSpecificKey<Int>()
    private static let popupQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "Sileo.PopupQueue", qos: .userInitiated)
        queue.setSpecific(key: popupQueueKey, value: popupQueueContext)
        return queue
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        TabBarController.singleton = self
        
        downloadsController = UINavigationController(rootViewController: DownloadManager.shared.viewController)
        downloadsController?.isNavigationBarHidden = true
        downloadsController?.popupItem.title = ""
        downloadsController?.popupItem.subtitle = ""
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        updateSileoColors()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.updatePopup()
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        shouldSelectIndex = tabBarController.selectedIndex
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if shouldSelectIndex == tabBarController.selectedIndex {
            if let splitViewController = viewController as? UISplitViewController {
                if let navController = splitViewController.viewControllers[0] as? UINavigationController {
                    navController.popToRootViewController(animated: true)
                }
            }
        }
        if tabBarController.selectedIndex == 4 && shouldSelectIndex == 4 {
            if let navController = tabBarController.viewControllers?[4] as? SileoNavigationController,
               let packageList = navController.viewControllers[0] as? PackageListViewController {
                packageList.searchController.searchBar.becomeFirstResponder()
            }
        }
        if tabBarController.selectedIndex == 3 && shouldSelectIndex == 3 {
            if let navController = tabBarController.viewControllers?[3] as? SileoNavigationController,
               let packageList = navController.viewControllers[0] as? PackageListViewController,
               let collectionView = packageList.collectionView {
                let yVal = -1 * collectionView.adjustedContentInset.top
                collectionView.setContentOffset(CGPoint(x: 0, y: yVal), animated: true)
            }
        }
        if tabBarController.selectedIndex ==  2 && !fuckedUpSources {
            if let sourcesSVC = tabBarController.viewControllers?[2] as? UISplitViewController,
               let sourcesNaVC = sourcesSVC.viewControllers[0] as? SileoNavigationController {
                if sourcesNaVC.presentedViewController == nil {
                    sourcesNaVC.popToRootViewController(animated: false)
                }
            }
            fuckedUpSources = true
        }
        if viewController as? SileoNavigationController != nil { return }
        if viewController as? SourcesSplitViewController != nil { return }
        fatalError("View Controller mismatch")
    }
    
    func presentPopup() {
        presentPopup(completion: nil)
    }
    
    func presentPopup(animated:Bool = true, completion: (() -> Void)?) {
        NSLog("SileoLog: TabBarController.presentPopup \(popupIsPresented), \(downloadsController), \(completion)")

        guard let downloadsController = downloadsController, !popupIsPresented else {
            if let completion = completion {
                completion()
            }
            return
        }
        
        popupLock.wait()
        defer {
            popupLock.signal()
        }
        
        popupIsPresented = true
        self.popupContentView.popupCloseButtonAutomaticallyUnobstructsTopBars = false
        self.popupBar.toolbar.tag = WHITE_BLUR_TAG
        self.popupBar.barStyle = .prominent
        
        self.updateSileoColors()
        
        self.popupBar.toolbar.setBackgroundImage(nil, forToolbarPosition: .any, barMetrics: .default)
        self.popupBar.tabBarHeight = self.tabBar.frame.height
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.popupBar.isInlineWithTabBar = true
            self.popupBar.tabBarHeight += 1
        }
        self.popupBar.progressViewStyle = .bottom
        self.popupInteractionStyle = .drag
                
        TabBarController.popupQueue.async {
            self.popupQueueLock.wait()
            DispatchQueue.main.async {
                self.presentPopupBar(withContentViewController: downloadsController, animated: animated) {
                    completion?()
                    self.popupQueueLock.signal()
                }
            }
        }
        
        self.updateSileoColors()
    }
    
    func dismissPopup() {
        dismissPopup(completion: nil)
    }
    
    func dismissPopup(animated:Bool = true, completion: (() -> Void)?) {
        NSLog("SileoLog: TabBarController.dismissPopup \(popupIsPresented) \(completion)")

        guard popupIsPresented else {
            if let completion = completion {
                completion()
            }
            return
        }
        
        popupLock.wait()
        defer {
            popupLock.signal()
        }
        
        popupIsPresented = false
            
        TabBarController.popupQueue.async {
            self.popupQueueLock.wait()
            DispatchQueue.main.async {
                self.dismissPopupBar(animated: animated) {
                    completion?()
                    self.popupQueueLock.signal()
                }
            }
        }
    }
    
    func presentPopupController() {
        self.presentPopupController(completion: nil)
    }
    
    func presentPopupController(completion: (() -> Void)?) {
        NSLog("SileoLog: TabBarController.presentPopupController \(completion)")

        guard popupIsPresented else {
            if let completion = completion {
                completion()
            }
            return
        }
        
        popupLock.wait()
        defer {
            popupLock.signal()
        }
        
        self.openPopup(animated: true, completion: completion)
    }
    
    func dismissPopupController() {
        self.dismissPopupController(completion: nil)
    }
    
    func dismissPopupController(completion: (() -> Void)?) {
        NSLog("SileoLog: TabBarController.dismissPopupController \(completion)")

        guard popupIsPresented else {
            completion?()
            return
        }
        
        popupLock.wait()
        defer {
            popupLock.signal()
        }
        
        self.closePopup(animated: true, completion: completion)
    }
    
    func updatePopup() {
        updatePopup(completion: nil)
    }
    
    func updatePopup(animated:Bool = true, completion: (() -> Void)? = nil, bypass: Bool = false) {
        func hideRegardless() {
            if UIDevice.current.userInterfaceIdiom == .pad && self.view.frame.width >= ipadModeMinWidth {
                downloadsController?.popupItem.title = String(localizationKey: "Queued_Package_Status")
                downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), 0)
                self.presentPopup(animated: animated, completion: completion)
            } else {
                self.dismissPopup(animated: animated, completion: completion)
            }
        }
//we should never dismiss the popup if the queue is not empty (will cause TabBar to never display anymore)
//        if bypass {
//            hideRegardless()
//            return
//        }
        let manager = DownloadManager.shared
        NSLog("SileoLog: updatePopup(\(completion),\(bypass)) : \(self.view.frame.width) : \(manager.lockedForInstallation) \(manager.downloadingPackages()) \(manager.operationCount()) \(manager.readyPackages()) \(manager.uninstallingPackages())")
        if manager.lockedForInstallation {
            downloadsController?.popupItem.title = String(localizationKey: "Installing_Package_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.readyPackages())
            downloadsController?.popupItem.progress = Float(manager.totalProgress)
            self.presentPopup(completion: completion)
        } else if manager.downloadingPackages() > 0 {
            downloadsController?.popupItem.title = String(localizationKey: "Downloading_Package_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.downloadingPackages())
            downloadsController?.popupItem.progress = 0
            self.presentPopup(completion: completion)
        } else if manager.operationCount() > 0 {
            downloadsController?.popupItem.title = String(localizationKey: "Queued_Package_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.operationCount())
            downloadsController?.popupItem.progress = 0
            self.presentPopup(completion: completion)
        } else if manager.readyPackages() > 0 {
            downloadsController?.popupItem.title = String(localizationKey: "Ready_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.readyPackages())
            downloadsController?.popupItem.progress = 0
            self.presentPopup(completion: completion)
        } else if manager.uninstallingPackages() > 0 {
            downloadsController?.popupItem.title = String(localizationKey: "Removal_Queued_Package_Status")
            downloadsController?.popupItem.subtitle = String(format: String(localizationKey: "Package_Queue_Count"), manager.uninstallingPackages())
            downloadsController?.popupItem.progress = 0
            self.presentPopup(completion: completion)
        } else {
            DispatchQueue.main.async {
                //requires async due the deadlock: dismissPopupController->(LNPopupController)->viewDidLayoutSubviews->updatePopup->dismissPopup on iphone mode on ipad
                hideRegardless()
            }
        }
    }
    
    override var bottomDockingViewForPopupBar: UIView? {
        self.tabBar
    }
    
    override var defaultFrameForBottomDockingView: CGRect {
        NSLog("SileoLog: TabBarController.defaultFrameForBottomDockingView")
        var tabBarFrame = self.tabBar.frame
        tabBarFrame.origin.y = self.view.bounds.height - tabBarFrame.height
        if UIDevice.current.userInterfaceIdiom == .pad {
            tabBarFrame.origin.x = 0
            tabBarFrame.size.width = self.view.bounds.width
            if tabBarFrame.width >= ipadModeMinWidth {
                tabBarFrame.size.width -= 320
            }
        }
        return tabBarFrame
    }
    
    override var insetsForBottomDockingView: UIEdgeInsets {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if self.view.bounds.width < ipadModeMinWidth {
                return .zero
            }
            return UIEdgeInsets(top: self.tabBar.frame.height, left: self.view.bounds.width - 320, bottom: 0, right: 0)
        }
        return .zero
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateSileoColors()
    }
    
    @objc func updateSileoColors() {
        if UIColor.isDarkModeEnabled {
            self.popupBar.systemBarStyle = .black
            self.popupBar.toolbar.barStyle = .black
        } else {
            self.popupBar.systemBarStyle = .default
            self.popupBar.toolbar.barStyle = .default
        }
    }
    
    override func viewDidLayoutSubviews() {
        NSLog("SileoLog: TabBarController.viewDidLayoutSubviews")
        super.viewDidLayoutSubviews()
        
        self.tabBar.itemPositioning = .centered
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.updatePopup(animated: false)
        }
    }
    
    public func displayError(_ string: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.displayError(string)
            }
            return
        }
        let alertController = UIAlertController(title: String(localizationKey: "Unknown", type: .error), message: string, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .default))
        self.present(alertController, animated: true, completion: nil)
    }
}
