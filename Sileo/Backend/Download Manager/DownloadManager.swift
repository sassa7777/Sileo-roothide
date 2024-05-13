//
//  DownloadManager.swift
//  Sileo
//
//  Created by CoolStar on 8/2/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import Evander

public enum DownloadManagerQueue: Int {
    case upgrades
    case installations
    case uninstallations
    case installdeps
    case uninstalldeps
    case none
}

final class DownloadManager {
    static let lockStateChangeNotification = Notification.Name("SileoDownloadManagerLockStateChanged")
    static let aptQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "Sileo.AptQueue", qos: .userInitiated)
        queue.setSpecific(key: DownloadManager.queueKey, value: DownloadManager.queueContext)
        return queue
    }()
    public static let queueKey = DispatchSpecificKey<Int>()
    public static let queueContext = 50
    
    enum Error: LocalizedError {
        case hashMismatch(packageHash: String, refHash: String)
        case untrustedPackage(packageID: String)
        case debugNotAllowed
        
        public var errorDescription: String? {
            switch self {
            case let .hashMismatch(packageHash, refHash):
                return String(format: String(localizationKey: "Download_Hash_Mismatch", type: .error), packageHash, refHash)
            case let .untrustedPackage(packageID):
                return String(format: String(localizationKey: "Untrusted_Package", type: .error), packageID)
            case .debugNotAllowed:
                return "Packages cannot be added to the queue during install"
            }
        }
    }
    
    enum PackageHashType: String, CaseIterable {
        case sha256
        case sha512
        
        var hashType: HashType {
            switch self {
            case .sha256: return .sha256
            case .sha512: return .sha512
            }
        }
    }
    
    static let shared = DownloadManager()
    
    public var lockedForInstallation = false {
        didSet {
            // NotificationCenter.default.post(name: DownloadManager.lockStateChangeNotification, object: nil)
        }
    }
    public var totalProgress = CGFloat(0)
    
    var upgrades = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var installations = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var uninstallations = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var installdeps = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var uninstalldeps = SafeSet<DownloadPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    var errors = SafeSet<APTBrokenPackage>(queue: aptQueue, key: queueKey, context: queueContext)
    
    private var currentDownloads = 0
    public var queueStarted = false
    var downloads = SafeDictionary<String,Download>(queue: aptQueue, key: queueKey, context: queueContext)
    var cachedFiles = SafeArray<URL>(queue: aptQueue, key: queueKey, context: queueContext)
        
    var repoDownloadOverrideProviders = SafeDictionary<String, Set<AnyHashable>>(queue: aptQueue, key: queueKey, context: queueContext)
    
    var viewController: DownloadsTableViewController
    
    init() {
        viewController = DownloadsTableViewController(nibName: "DownloadsTableViewController", bundle: nil)
    }
    
    public func installingPackages() -> Int {
        upgrades.count + installations.count + installdeps.count
    }
    
    public func uninstallingPackages() -> Int {
        uninstallations.count + uninstalldeps.count
    }
    
    public func operationCount() -> Int {
        upgrades.count + installations.count + uninstallations.count + installdeps.count + uninstalldeps.count
    }
        
    public func downloadingPackages() -> Int {
        var downloadsCount = 0
        for keyValue in downloads.raw where keyValue.value.progress < 1 {
            downloadsCount += 1
        }
        return downloadsCount
    }
    
    public func readyPackages() -> Int {
        var readyCount = 0
        for keyValue in downloads.raw {
            let download = keyValue.value
            if download.progress == 1 && download.success == true {
                readyCount += 1
            }
        }
        return readyCount
    }
    
    public func verifyComplete() -> Bool {
        let allRawDownloads = upgrades.raw.union(installations.raw).union(installdeps.raw)
        for dlPackage in allRawDownloads {
            guard let download = downloads[dlPackage.package.packageID],
                  download.success else { return false }
        }
        return true
    }
    
    func startPackageDownload(download: Download) {
        let package = download.package
        var filename = package.filename ?? ""
        
        var packageRepo: Repo?
        for repo in RepoManager.shared.repoList where repo.rawEntry == package.sourceFile {
            packageRepo = repo
        }
        
        if package.package.contains("/") {
            filename = URL(fileURLWithPath: package.package).absoluteString
        } else if !filename.hasPrefix("https://") && !filename.hasPrefix("http://") {
            filename = URL(string: packageRepo?.rawURL ?? "")?.appendingPathComponent(filename).absoluteString ?? ""
        }
        
        // If it's a local file we can verify it immediately
        if self.verify(download: download) {
            download.progress = 1
            download.success = true
            download.completed = true
            Self.aptQueue.async { [self] in
                if self.verifyComplete() {
                    self.viewController.reloadControlsOnly()
                } else {
                    NSLog("SileoLog: startMoreDownloads4")
                    startMoreDownloads()
                }
            }
            return
        }
        
        download.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            download.task?.cancel()
            if let backgroundTaskIdentifier = download.backgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
            download.backgroundTask = nil
        })
        
        // See if theres an overriding web URL for downloading the package from
        currentDownloads += 1
        self.overrideDownloadURL(package: package, repo: packageRepo) { errorMessage, url in
            if url == nil && errorMessage != nil {
                self.currentDownloads -= 1
                download.failureReason = errorMessage
                DispatchQueue.main.async {
                    self.viewController.reloadDownload(package: download.package)
                    TabBarController.singleton?.updatePopup()
                }
                return
            }
            let downloadURL = url ?? URL(string: filename)
            download.started = true
            download.failureReason = nil
            download.task = RepoManager.shared.queue(from: downloadURL, progress: { task, progress in
                download.message = nil
                download.progress = CGFloat(progress.fractionCompleted)
                download.totalBytesWritten = progress.total
                download.totalBytesExpectedToWrite = progress.expected
                DispatchQueue.main.async {
                    self.viewController.reloadDownload(package: package)
                }
            }, success: { task, fileURL in
                self.currentDownloads -= 1
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes?[FileAttributeKey.size] as? Int
                let fileSizeStr = String(format: "%ld", fileSize ?? 0)
                download.message = nil
                if let backgroundTaskIdentifier = download.backgroundTask {
                    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                }
                download.backgroundTask = nil
                download.message = nil
                if !package.package.contains("/") && (fileSizeStr != package.size) {
                    download.failureReason = String(format: String(localizationKey: "Download_Size_Mismatch", type: .error),
                                                    package.size ?? "nil", fileSizeStr)
                    download.success = false
                    download.progress = 0
                } else {
                    do {
                        download.success = try self.verify(download: download, fileURL: fileURL)
                    } catch let error {
                        download.success = false
                        download.failureReason = error.localizedDescription
                    }
                    if download.success {
                        download.progress = 1
                    } else {
                        download.progress = 0
                    }
                    
                    #if TARGET_SANDBOX || targetEnvironment(simulator)
                    try? FileManager.default.removeItem(at: fileURL)
                    #endif
                    
                    Self.aptQueue.async { [self] in
                        if self.verifyComplete() {
                            DispatchQueue.main.async {
                                self.viewController.reloadDownload(package: download.package)
                                TabBarController.singleton?.updatePopup()
                                self.viewController.reloadControlsOnly()
                            }
                            
                        } else {
                            NSLog("SileoLog: startMoreDownloads5")
                            startMoreDownloads()
                        }
                    }
                    return
                }
                NSLog("SileoLog: startMoreDownloads6")
                self.startMoreDownloads()
            }, failure: { task, statusCode, error in
                self.currentDownloads -= 1
                download.failureReason = error?.localizedDescription ?? String(format: String(localizationKey: "Download_Failing_Status_Code", type: .error), statusCode)
                download.message = nil
                if let backgroundTaskIdentifier = download.backgroundTask {
                    UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                }
                download.backgroundTask = nil
                DispatchQueue.main.async {
                    self.viewController.reloadDownload(package: download.package)
                    self.viewController.reloadControlsOnly()
                    TabBarController.singleton?.updatePopup()
                }
                NSLog("SileoLog: startMoreDownloads7")
                self.startMoreDownloads()
            }, waiting: { task, message in
                download.message = message
                DispatchQueue.main.async {
                    self.viewController.reloadDownload(package: package)
                }
            })
            download.task?.resume()
            
            self.viewController.reloadDownload(package: package)
        }
    }
    
    func startMoreDownloads() {
        NSLog("SileoLog: startMoreDownloads")
//        Thread.callStackSymbols.forEach{NSLog("SileoLog: callstack=\($0)")}
        DownloadManager.aptQueue.async { [self] in
            // We don't want more than one download at a time
            guard currentDownloads <= 3 else { return }
            // Get a list of downloads that need to take place
            let allRawDownloads = upgrades.raw.union(installations.raw).union(installdeps.raw)
            for dlPackage in allRawDownloads {
                // Get the download object, we don't want to create multiple
                let download: Download
                let package = dlPackage.package
                if let tmp = downloads[package.packageID] {
                    download = tmp
                } else {
                    download = Download(package: package)
                    downloads[package.packageID] = download
                }
                
                // Means download has already started / completed
                if download.queued { continue }
                download.queued = true
                startPackageDownload(download: download)
                
                guard currentDownloads <= 3 else { break }
            }
        }
    }
 
    public func download(package: String) -> Download? {
        downloads[package]
    }
    
    private func aptEncoded(string: String, isArch: Bool) -> String {
        var encodedString = string.replacingOccurrences(of: "_", with: "%5f")
        encodedString = encodedString.replacingOccurrences(of: ":", with: "%3a")
        if isArch {
            encodedString = encodedString.replacingOccurrences(of: ".", with: "%2e")
        }
        return encodedString
    }
    
    private func verify(download: Download) -> Bool {
        let package = download.package
        
        let packageID = aptEncoded(string: package.packageID, isArch: false)
        let version = aptEncoded(string: package.version, isArch: false)
        let architecture = aptEncoded(string: package.architecture ?? "", isArch: true)
        
        let destFileName = "\(CommandPath.prefix)/var/cache/apt/archives/\(packageID)_\(version)_\(architecture).deb"
        let destURL = URL(fileURLWithPath: destFileName)
        
        if !FileManager.default.fileExists(atPath: destFileName) {
            if package.package.contains("/") {
                moveFileAsRoot(from: URL(fileURLWithPath: package.package), to: URL(fileURLWithPath: destFileName))
                DownloadManager.shared.cachedFiles.append(URL(fileURLWithPath: package.package))
                package.debPath = destFileName
                return FileManager.default.fileExists(atPath: destFileName)
            }
            return false
        }
        
        let packageControl = package.rawControl
        
        if !package.package.contains("/") {
            let supportedHashTypes = PackageHashType.allCases.compactMap { type in packageControl[type.rawValue].map { (type, $0) } }
            let packageContainsHashes = !supportedHashTypes.isEmpty
            
            guard packageContainsHashes else { return false }
            
            let packageIsValid = supportedHashTypes.allSatisfy {
                let hash = packageControl[$1]
                guard let refHash = destURL.hash(ofType: $0.hashType),
                      refHash == hash else { return false }
                return true
            }
            guard packageIsValid else {
                return false
            }
        }
        
        return true
    }
    
    private func verify(download: Download, fileURL: URL) throws -> Bool {
        let package = download.package
        let packageControl = package.rawControl
        
        if !package.package.contains("/") {
            let supportedHashTypes = PackageHashType.allCases.compactMap { type in packageControl[type.rawValue].map { (type, $0) } }
            let packageContainsHashes = !supportedHashTypes.isEmpty
            
            guard packageContainsHashes else {
                throw Error.untrustedPackage(packageID: package.package)
            }
            
            var badHash = ""
            var badRefHash = ""
            
            let packageIsValid = supportedHashTypes.allSatisfy {
                let hash = $1
                guard let refHash = fileURL.hash(ofType: $0.hashType) else { return false }
              
                if hash != refHash {
                    badHash = hash
                    badRefHash = refHash
                    return false
                } else {
                    return true
                }
            }
            guard packageIsValid else {
                throw Error.hashMismatch(packageHash: badHash, refHash: badRefHash)
            }
        }
        
        #if !TARGET_SANDBOX && !targetEnvironment(simulator)
        let packageID = aptEncoded(string: package.packageID, isArch: false)
        let version = aptEncoded(string: package.version, isArch: false)
        let architecture = aptEncoded(string: package.architecture ?? "", isArch: true)
        
        let destFileName = "\(CommandPath.prefix)/var/cache/apt/archives/\(packageID)_\(version)_\(architecture).deb"
        let destURL = URL(fileURLWithPath: destFileName)

        moveFileAsRoot(from: fileURL, to: destURL)
        #endif
        DownloadManager.shared.cachedFiles.append(fileURL)
        return true
    }
    
    //running in aptQueue
    private func recheckTotalOps() throws {
        if Thread.isMainThread {
            fatalError("This cannot be called from the main thread!")
        }
        
        // Clear any current depends
        installdeps.removeAll()
        uninstalldeps.removeAll()
        errors.removeAll()
        
        // Get a total of depends to be installed and break if empty
        let installationsAndUpgrades = self.installations.raw.union(self.upgrades.raw)
        guard !(installationsAndUpgrades.isEmpty && uninstallations.isEmpty) else {
            return
        }
        let all = (installationsAndUpgrades.union(uninstallations.raw)).map { $0.package }
        do {
            // Run the dep accelerator for any packages that have not already been cared about
            try DependencyResolverAccelerator.shared.getDependencies(packages: all)
        } catch {
            throw error
        }
        #if TARGET_SANDBOX || targetEnvironment(simulator)
        return
        #endif
        var aptOutput: APTOutput
        do {
            // Get the full list of packages to be installed and removed from apt
            aptOutput = try APTWrapper.operationList(installList: installationsAndUpgrades, removeList: uninstallations.raw)
            NSLog("SileoLog: aptOutput=\(aptOutput.operations), \(aptOutput.conflicts)")
        } catch {
            throw error
        }
        
        // Get every package to be uninstalled
        var uninstallIdentifiers = [String]()
        for operation in aptOutput.operations where operation.type == .remove {
            uninstallIdentifiers.append(operation.packageID)
        }
        
        var uninstallations = uninstallations.raw
        let rawUninstalls = PackageListManager.shared.packages(identifiers: uninstallIdentifiers, sorted: false, packages: Array(PackageListManager.shared.installedPackages.values))
        guard rawUninstalls.count == uninstallIdentifiers.count else {
            rawUninstalls.map({NSLog("SileoLog: rawUninstalls=\($0.packageID) \($0.package)")})
            uninstallIdentifiers.map({NSLog("SileoLog: uninstallIdentifiers=\($0)")})
            throw APTParserErrors.blankJsonOutput(error: "Uninstall Identifiers Mismatch")
        }
        var uninstallDeps = Set<DownloadPackage>(rawUninstalls.compactMap { DownloadPackage(package: $0) })
        
        // Get the list of packages to be installed, including depends
        var installIdentifiers = [String]()
        var installDepOperation = [String: [(String, String)]]()
        for operation in aptOutput.operations where operation.type == .install {
            installIdentifiers.append(operation.packageID)
            //there may be multiple repos in the release: {"Version":"2021.07.18","Package":"chariz-keyring","Release":"192.168.2.171, local-deb [all]","Type":"Inst"}
            guard let releases = operation.release?.split(separator: ",") else { continue }
            for release in releases {
                guard let host = release.trimmingCharacters(in: .whitespaces).split(separator: " ").first else { continue }
                
                if var hostArray = installDepOperation[String(host)] {
                    hostArray.append((operation.packageID, operation.version))
                    installDepOperation[String(host)] = hostArray
                } else {
                    installDepOperation[String(host)] = [(operation.packageID, operation.version)]
                }
            }
        }
        NSLog("SileoLog: installIdentifiers=\(installIdentifiers), installDepOperation=\(installDepOperation)")
        var installIndentifiersReference = installIdentifiers
        var rawInstalls = ContiguousArray<Package>()
        for (host, packages) in installDepOperation {
            for aptPackage in packages {
                
                guard installIdentifiers.contains(aptPackage.0) else { continue } //already found one
                
                if host == "local-deb" { //preferred local package
                    if let localPackage = PackageListManager.shared.localPackages[aptPackage.0] {
                        if checkRootHide(localPackage) {
                            if localPackage.version == aptPackage.1 {
                                rawInstalls.append(localPackage)
                                installIdentifiers.removeAll { $0 == aptPackage.0 }
                            }
                        }
                    }
                } else {
                    //if let repo = RepoManager.shared.repoList.first(where: {return $0.url?.host == host }) {
                    // a host may have multiple repos
                    for repo in RepoManager.shared.repoList where repo.url?.host == host {
                        NSLog("SileoLog: package=\(aptPackage.0),\(aptPackage.1)")
                        if let repoPackage = repo.packageDict[aptPackage.0] {
                            NSLog("SileoLog: repoPackage=\(repoPackage.packageID),\(repoPackage.version)")
                            if checkRootHide(repoPackage) {
                                if repoPackage.version == aptPackage.1 {
                                    rawInstalls.append(repoPackage)
                                    installIdentifiers.removeAll { $0 == aptPackage.0 }
                                } else if let version = repoPackage.getVersion(aptPackage.1) {
                                    rawInstalls.append(version)
                                    installIdentifiers.removeAll { $0 == aptPackage.0 }
                                }
                            }
                        }
                    }
                }
            }
        }
            
        NSLog("SileoLog: rawInstalls=\(rawInstalls)")
        rawInstalls += PackageListManager.shared.packages(identifiers: installIdentifiers, sorted: false)
        NSLog("SileoLog: rawInstalls=\(rawInstalls)")
        
        for package in rawInstalls {
            if !checkRootHide(package) {
                let compat = APTBrokenPackage.ConflictingPackage(package:"roothide", conflict:.conflicts)
                let brokenPackage = APTBrokenPackage(packageID: package.packageID, conflictingPackages: [compat])
                aptOutput.conflicts.append(brokenPackage)
//                rawInstalls.removeAll { $0 == package}
//                installIdentifiers.removeAll { $0 == package.packageID}
//                installIndentifiersReference.removeAll { $0 == package.packageID}
            }
        }
        
        guard rawInstalls.count == installIndentifiersReference.count else {
            rawUninstalls.map({NSLog("SileoLog: rawInstalls=\($0.packageID) \($0.package)")})
            rawUninstalls.map({NSLog("SileoLog: installIndentifiersReference=\($0)")})
            throw APTParserErrors.blankJsonOutput(error: "Install Identifier Mismatch for Identifiers")
        }
        var installDeps = Set<DownloadPackage>(rawInstalls.compactMap { DownloadPackage(package: $0) })
        var installations = installations.raw
        var upgrades = upgrades.raw

        if aptOutput.conflicts.isEmpty {
            installations.removeAll { uninstallDeps.contains($0) }
            uninstallations.removeAll { installDeps.contains($0) }
            
            installations.removeAll { !installDeps.contains($0) }
            upgrades.removeAll { !installDeps.contains($0) }
            uninstallations.removeAll { !uninstallDeps.contains($0) }
            uninstallDeps.removeAll { uninstallations.contains($0) }
            installDeps.removeAll { installations.contains($0) }
            installDeps.removeAll { upgrades.contains($0) }
        }
  
        self.upgrades.setTo(upgrades)
        self.installations.setTo(installations)
        self.installdeps.setTo(installDeps)
        self.uninstallations.setTo(uninstallations)
        self.uninstalldeps.setTo(uninstallDeps)
        self.errors.setTo(Set<APTBrokenPackage>(aptOutput.conflicts))
        
        NSLog("SileoLog: upgrades=\(upgrades.count), installations=\(installations.count), installdeps=\(installdeps.count) uninstallations=\(uninstallations.count) uninstalldeps=\(uninstalldeps.count) errors=\(errors.count)")
        for p in self.upgrades.raw { NSLog("SileoLog: upgrades: \(p.package.packageID):\(p.package.package), \(p.package.sourceRepo?.url)") }
        for p in self.installations.raw { NSLog("SileoLog: installations: \(p.package.packageID):\(p.package.package), \(p.package.sourceRepo?.url)") }
        for p in self.installdeps.raw { NSLog("SileoLog: installdeps: \(p.package.packageID):\(p.package.package), \(p.package.sourceRepo?.url)") }
        for p in self.uninstallations.raw { NSLog("SileoLog: uninstallations: \(p.package.packageID):\(p.package.package), \(p.package.sourceRepo?.url)") }
        for p in self.uninstalldeps.raw { NSLog("SileoLog: uninstalldeps: \(p.package.packageID):\(p.package.package), \(p.package.sourceRepo?.url)") }
    }
    
    private func checkInstalled() {
        let installedPackages = PackageListManager.shared.installedPackages.values
        for package in installedPackages {
            guard let newestPackage = PackageListManager.shared.newestPackage(identifier: package.package, repoContext: nil) else {
                continue
            }
            let downloadPackage = DownloadPackage(package: newestPackage)
            if package.eFlag == .reinstreq {
                if !installations.contains(downloadPackage) && !uninstallations.contains(downloadPackage) {
                    installations.insert(downloadPackage)
                }
            } else if package.eFlag == .ok {
                if package.wantInfo == .deinstall || package.wantInfo == .purge || package.status == .halfconfigured {
                    if !installations.contains(downloadPackage) && !uninstallations.contains(downloadPackage) {
                        uninstallations.insert(downloadPackage)
                    }
                }
            }
        }
    }
    
    public func cancelDownloads() {
        for download in downloads.raw.values {
            download.task?.cancel()
            if let backgroundTaskIdentifier = download.backgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
        }
        downloads.removeAll()
        currentDownloads = 0
    }
    
    public func removeAllItems() {
        upgrades.removeAll()
        installdeps.removeAll()
        installations.removeAll()
        uninstalldeps.removeAll()
        uninstallations.removeAll()
        errors.removeAll()
        for download in downloads.raw.values {
            download.task?.cancel()
            if let backgroundTaskIdentifier = download.backgroundTask {
                UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            }
        }
        downloads.removeAll()
        currentDownloads = 0
        self.checkInstalled()
    }
    
    public func reloadData(recheckPackages: Bool) {
        reloadData(recheckPackages: recheckPackages, completion: nil)
    }
    
    public func reloadData(recheckPackages: Bool, completion: (() -> Void)?) {
        DownloadManager.aptQueue.async { [self] in
            if recheckPackages {
                do {
                    try self.recheckTotalOps()
                } catch {
                    removeAllItems()
                    viewController.cancelDownload(nil)
                    TabBarController.singleton?.displayError(error.localizedDescription)
                }
            }
            DispatchQueue.main.async {
                self.viewController.reloadData()
                TabBarController.singleton?.updatePopup(completion: completion)
                NotificationCenter.default.post(name: PackageListManager.stateChange, object: nil)
            }
        }
    }
    
    public func find(package: Package) -> DownloadManagerQueue {
        let downloadPackage = DownloadPackage(package: package)
        if installations.contains(downloadPackage) {
            return .installations
        } else if uninstallations.contains(downloadPackage) {
            return .uninstallations
        } else if upgrades.contains(downloadPackage) {
            return .upgrades
        } else if installdeps.contains(downloadPackage) {
            return .installdeps
        } else if uninstalldeps.contains(downloadPackage) {
            return .uninstalldeps
        }
        return .none
    }
    
    public func find(package: String) -> DownloadManagerQueue {
        if installations.contains(where: { $0.package.package == package }) {
            return .installations
        } else if uninstallations.contains(where: { $0.package.package == package }) {
            return .uninstallations
        } else if upgrades.contains(where: { $0.package.package == package }) {
            return .upgrades
        } else if installdeps.contains(where: { $0.package.package == package }) {
            return .installdeps
        } else if uninstalldeps.contains(where: { $0.package.package == package }) {
            return .uninstalldeps
        }
        return .none
    }
    
    public func remove(package: String) {
        installations.remove { $0.package.package == package }
        upgrades.remove { $0.package.package == package }
        installdeps.remove { $0.package.package == package }
        uninstallations.remove { $0.package.package == package }
        uninstalldeps.remove { $0.package.package == package }
    }
    
    
    public func checkRootlessV2(package: Package, fileURL: URL) {
        NSLog("SileoLog: checkRootlessV2 \(package.package) \(fileURL)")
        
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: temp, withIntermediateDirectories: false, attributes: nil)
        
        var (status, output, errorOutput) = spawn(command: CommandPath.dpkgdeb, args: ["dpkg-deb", "-R", rootfs(fileURL.path), rootfs(temp.path)], root: true)
        guard status==0 else {return}
        
        let controlFilePath = temp.path.appending("/DEBIAN/control")
        
        spawn(command: CommandPath.chmod, args: ["chmod", "0666", rootfs(controlFilePath)], root: true)
        spawn(command: CommandPath.chmod, args: ["chmod", "0777", rootfs(temp.path.appending("/DEBIAN"))], root: true)
        
        guard var controlFileData = try? String(contentsOfFile: controlFilePath, encoding: .utf8) else {
            NSLog("SileoLog: read err \(controlFilePath)")
            return
        }
        
        controlFileData = controlFileData.replacingOccurrences(of: "Architecture: iphoneos-arm64", with: "Architecture: iphoneos-arm64e")
        
        do {
            try controlFileData.write(toFile: controlFilePath, atomically: true, encoding: .utf8)
        } catch {
            NSLog("SileoLog: write err \(error)")
            return
        }
        
        spawn(command: CommandPath.chmod, args: ["chmod", "0644", rootfs(controlFilePath)], root: true)
        spawn(command: CommandPath.chmod, args: ["chmod", "0755", rootfs(temp.path.appending("/DEBIAN"))], root: true)
        
        var newPkgPath = temp.path
        if FileManager.default.fileExists(atPath: temp.path.appending("/var/jb")) {
            newPkgPath = temp.path.appending("/var/jb")
            spawn(command: CommandPath.mv, args: ["mv", "-f", rootfs(temp.path.appending("/DEBIAN")), rootfs(newPkgPath)], root: true)
        }
        
        let outPath = temp.path.appending(".deb")
        
        (status, output, errorOutput) = spawn(command: CommandPath.dpkgdeb, args: ["dpkg-deb", "-b", rootfs(newPkgPath), rootfs(outPath)], root: true)
        guard status==0 else {return}

        guard let newPackage = PackageListManager.shared.package(url: URL(fileURLWithPath: outPath)) else {
            return
        }
        
        if checkRootHide(newPackage) {
            newPackage.rootlessV2 = true
            self.add(package: newPackage, queue: .installations)
            self.reloadData(recheckPackages: true)
        }
    }
    
    public func patchPackage(package: Package, fileURL: URL) {
            let packageID = self.aptEncoded(string: package.packageID, isArch: false)
            let version = self.aptEncoded(string: package.version, isArch: false)
            let architecture = self.aptEncoded(string: package.architecture ?? "", isArch: true)
            
            let extractionPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try! FileManager.default.createDirectory(at: extractionPath, withIntermediateDirectories: false, attributes: nil)
            
            let destFileName = "/\(extractionPath.path)/\(packageID)_\(version)_\(architecture).deb"
            let destURL = URL(fileURLWithPath: destFileName)
            NSLog("SileoLog: destURL=\(destURL.path)")
            try! FileManager.default.moveItem(at: fileURL, to: destURL)
        
            if IsAppAvailable("com.roothide.patcher") {
                if ShareFileToApp("com.roothide.patcher", destFileName) {
                    return
                }
            }
    
            let activity = UIActivityViewController(activityItems: [destURL], applicationActivities: nil)
            
            //for ipad, don't touch
            let sv = TabBarController.singleton!.view!
            activity.popoverPresentationController?.sourceView = sv
            activity.popoverPresentationController?.sourceRect = CGRect(x: sv.bounds.midX, y: sv.bounds.height, width: 0, height: 0)
            activity.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.down
            
            
            var controller:UIViewController = TabBarController.singleton!
            while controller.presentedViewController != nil && controller.presentedViewController?.isBeingDismissed==false {
                controller = controller.presentedViewController!
            }
            controller.present(activity, animated: true)
    }
    
    // call in main queue
    public func downloadDeb(package: Package, msg: String, handler: @escaping ((Package,URL) -> Void)) {
        var task:EvanderDownloader?
        
        let alert = UIAlertController(title: msg, message: msg, preferredStyle: .alert)
        
        let cancel = UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel) { _ in
            alert.dismiss(animated: true, completion: nil)
            task?.cancel()
        }
        alert.addAction(cancel)
        
        var controller:UIViewController = TabBarController.singleton!
        while controller.presentedViewController != nil && controller.presentedViewController?.isBeingDismissed==false {
            controller = controller.presentedViewController!
        }
        
        controller.present(alert, animated: true)
        
        func updateMsg(msg: String) {
            NSLog("SileoLog: updateMsg=\(msg)")
            DispatchQueue.main.async {
                alert.message = "\n \(msg) \n"
            }
        }
        
        func finishDownload(fileURL: URL) {
            NSLog("SileoLog: finishDownload=\(fileURL.path)")
            DispatchQueue.main.async {
                    alert.dismiss(animated: true, completion: {
                        handler(package,fileURL)
                })
            }
        }
        

        var filename = package.filename ?? ""
        
        var packageRepo: Repo?
        for repo in RepoManager.shared.repoList where repo.rawEntry == package.sourceFile {
            packageRepo = repo
        }
        
        if package.package.contains("/") {
            finishDownload(fileURL: URL(fileURLWithPath: package.package))
            return
        } else if !filename.hasPrefix("https://") && !filename.hasPrefix("http://") {
            filename = URL(string: packageRepo?.rawURL ?? "")?.appendingPathComponent(filename).absoluteString ?? ""
        }
        
        // See if theres an overriding web URL for downloading the package from
        self.overrideDownloadURL(package: package, repo: packageRepo) { errorMessage, url in
            if url == nil && errorMessage != nil {
                updateMsg(msg: "\(errorMessage)")
                return
            }
            let downloadURL = url ?? URL(string: filename)
            NSLog("SileoLog: downloadURL=\(downloadURL)")
            task = RepoManager.shared.queue(from: downloadURL, progress: { task, progress in
                var msg:String
                if progress.expected==NSURLSessionTransferSizeUnknown {
                    msg = "\(progress.total) bytes ..."
                } else {
                    msg = "\(Int(progress.fractionCompleted * 100))% ..."
                }
                updateMsg(msg: msg)
            }, success: { task, fileURL in
                
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes?[FileAttributeKey.size] as? Int
                let fileSizeStr = String(format: "%ld", fileSize ?? 0)
                
                if !package.package.contains("/") && (fileSizeStr != package.size) {
                    let failureReason = String(format: String(localizationKey: "Download_Size_Mismatch", type: .error),
                                               package.size ?? "nil", fileSizeStr)
                    updateMsg(msg: "\(failureReason)")
                } else {
                    finishDownload(fileURL: fileURL)
                }
                
            }, failure: { task, statusCode, error in
                let failureReason = error?.localizedDescription ?? String(format: String(localizationKey: "Download_Failing_Status_Code", type: .error), statusCode)
                
                updateMsg(msg: "\(failureReason)")
                
            }, waiting: { task, message in
                updateMsg(msg: "\(message)")
            })
            task?.resume()
        }
    }
    
    public func add(package: Package, queue: DownloadManagerQueue, approved: Bool = false) {
        NSLog("SileoLog: addPackage=\(package.name), queue=\(queue.rawValue), approved=\(approved) package=\(package.package), repo=\(package.sourceRepo?.url) depends=\(package.rawControl["depends"]) arch=\(package.architecture)")
        //Thread.callStackSymbols.forEach{NSLog("SileoLog: callstack=\($0)")}

        CanisterResolver.shared.ingest(packages: [package])
        
        if queue != .uninstallations && queue != .uninstalldeps {
            if !checkRootHide(package) {
                
                if package.tags.contains(.roothide) && FileManager.default.fileExists(atPath: jbroot("/usr/lib/libroot.dylib")) {
                    NSLog("SileoLog: roothide suppport: \(package.package)")
                    self.downloadDeb(package:package, msg: String(localizationKey: "Loading"), handler: self.checkRootlessV2)
                    return
                }
                
                DispatchQueue.main.async {
                    NSLog("SileoLog: not updated for roothide: \(package.package) \(package.architecture)")
                    
                    let title = String(localizationKey: "Not Updated")
                    
                    let msg = ["apt.procurs.us","ellekit.space"].contains(package.sourceRepo?.url?.host) ? String(localizationKey: "please contact @roothideDev to update it") : String(localizationKey: "You can contact the developer of this package to update it for roothide, or you can try to convert it via roothide Patcher.")
                    
                    let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
                    
                    let installedPatcher = PackageListManager.shared.installedPackage(identifier: "com.roothide.patcher") != nil
                    
                    let patchAction = UIAlertAction(title: String(localizationKey: installedPatcher ? "Convert" : "Get Patcher"), style: .destructive) { _ in
                        alert.dismiss(animated: true, completion: {
                            var presentModally = false
                            if installedPatcher {
                                self.downloadDeb(package:package, msg: String(localizationKey: "Downloading_Package_Status"), handler: self.patchPackage)
                            }
                            else if let packageview = URLManager.viewController(url: URL(string: "sileo://package/com.roothide.patcher"), isExternalOpen: true, presentModally: &presentModally) {
                                
                                var controller:UIViewController = TabBarController.singleton!
                                while controller.presentedViewController != nil && controller.presentedViewController?.isBeingDismissed==false {
                                    controller = controller.presentedViewController!
                                }
                                controller.present(packageview, animated: true)
                            }
                        })
                    }
                    
                    if ["apt.procurs.us","ellekit.space"].contains(package.sourceRepo?.url?.host)==false {
                        alert.addAction(patchAction)
                    }
                    
                    let okAction = UIAlertAction(title: (package.sourceRepo?.url?.host == "apt.procurs.us") ? String(localizationKey: "OK") : String(localizationKey: "Cancel"), style: .cancel) { _ in
                        alert.dismiss(animated: true, completion: nil)
                    }
                    alert.addAction(okAction)
                    
                    var controller:UIViewController = TabBarController.singleton!
                    while controller.presentedViewController != nil && controller.presentedViewController?.isBeingDismissed==false {
                        controller = controller.presentedViewController!
                    }
                    controller.present(alert, animated: true)
                }
                return
            }
        }
        

        let downloadPackage = DownloadPackage(package: package)
        let found = find(package: package.package)
        if found == queue { return }
        remove(downloadPackage: downloadPackage, queue: found)

        switch queue {
        case .none:
            return
        case .installations:
            installations.insert(downloadPackage)
        case .uninstallations:
            if approved == false && isEssential(downloadPackage.package) {
                let message = String(format: String(localizationKey: "Essential_Warning"),
                                     "\n\(downloadPackage.package.name ?? downloadPackage.package.packageID)")
                let alert = UIAlertController(title: String(localizationKey: "Warning"),
                                              message: message,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .default, handler: { _ in
                    alert.dismiss(animated: true)
                }))
                alert.addAction(UIAlertAction(title: String(localizationKey: "Dangerous_Repo.Last_Chance.Continue"), style: .destructive, handler: { _ in
                    self.add(package: downloadPackage.package, queue: .uninstallations, approved: true)
                    self.reloadData(recheckPackages: true)
                }))
                TabBarController.singleton?.present(alert, animated: true)
                return
            }
            uninstallations.insert(downloadPackage)
        case .upgrades:
            upgrades.insert(downloadPackage)
        case .installdeps:
            installdeps.insert(downloadPackage)
        case .uninstalldeps:
            uninstalldeps.insert(downloadPackage)
        }
    }
    
    public func upgradeAll(packages: Set<Package>, _ completion: @escaping () -> ()) {
        Self.aptQueue.async { [self] in
            var packages = packages
            let mapped = upgrades.map { $0.package.package }
            packages.removeAll { mapped.contains($0.package) }
            for package in packages {
                let downloadPackage = DownloadPackage(package: package)
                let found = find(package: package.package)
                if found == .upgrades { continue }
                remove(downloadPackage: downloadPackage, queue: found)
                upgrades.insert(downloadPackage)
            }
            completion()
        }
    }
  
    public func remove(package: Package, queue: DownloadManagerQueue) {
        let downloadPackage = DownloadPackage(package: package)
        remove(downloadPackage: downloadPackage, queue: queue)
    }
    
    public func remove(downloadPackage: DownloadPackage, queue: DownloadManagerQueue) {
        switch queue {
        case .none:
            return
        case .installations:
            installations.remove(downloadPackage)
        case .uninstallations:
            uninstallations.remove(downloadPackage)
        case .upgrades:
            upgrades.remove(downloadPackage)
        case .installdeps:
            installdeps.remove(downloadPackage)
        case .uninstalldeps:
            uninstalldeps.remove(downloadPackage)
        }
    }

    public func register(downloadOverrideProvider: DownloadOverrideProviding, repo: Repo) {
        if repoDownloadOverrideProviders[repo.repoURL] == nil {
            repoDownloadOverrideProviders[repo.repoURL] = Set()
        }
        repoDownloadOverrideProviders[repo.repoURL]?.insert(downloadOverrideProvider.hashableObject)
    }
    
    public func deregister(downloadOverrideProvider: DownloadOverrideProviding, repo: Repo) {
        repoDownloadOverrideProviders[repo.repoURL]?.remove(downloadOverrideProvider.hashableObject)
    }
    
    public func deregister(downloadOverrideProvider: DownloadOverrideProviding) {
        for keyVal in repoDownloadOverrideProviders.raw {
            repoDownloadOverrideProviders[keyVal.key]?.remove(downloadOverrideProvider.hashableObject)
        }
    }
    
    private func overrideDownloadURL(package: Package, repo: Repo?, completionHandler: @escaping (String?, URL?) -> Void) {
        guard let repo = repo,
              let providers = repoDownloadOverrideProviders[repo.repoURL],
              !providers.isEmpty else {
            return completionHandler(nil, nil)
        }

        // The number of providers checked so far
        var checked = 0
        let total = providers.count
        for obj in providers {
            guard let downloadProvider = obj as? DownloadOverrideProviding else {
                continue
            }
            var willProvideURL = false
            willProvideURL = downloadProvider.downloadURL(for: package, from: repo, completionHandler: { errorMessage, url in
                // Ensure that this provider didn't say no and then try to call the completion handler
                if willProvideURL {
                    completionHandler(errorMessage, url)
                }
            })
            checked += 1
            if willProvideURL {
                break
            } else if checked >= total {
                // No providers offered an override URL for this download
                completionHandler(nil, nil)
            }
        }
    }
    
    public func repoRefresh() {
        NSLog("SileoLog: repoRefresh lock=\(lockedForInstallation) operationCount=\(operationCount()) ")
        if lockedForInstallation { return }
        let plm = PackageListManager.shared
        var reloadNeeded = false
//        if operationCount() != 0 {
//            reloadNeeded = true
//            let savedUpgrades: [(String, String)] = upgrades.map({
//                let pkg = $0.package
//                return (pkg.packageID, pkg.version)
//            })
//            let savedInstalls: [(String, String)] = installations.map({
//                let pkg = $0.package
//                return (pkg.packageID, pkg.version)
//            })
//
//            upgrades.removeAll()
//            installations.removeAll()
//            installdeps.removeAll()
//            uninstalldeps.removeAll()
//
//            for tuple in savedUpgrades {
//                let id = tuple.0
//                let version = tuple.1
//
//                if let pkg = plm.package(identifier: id, version: version) ?? plm.newestPackage(identifier: id, repoContext: nil) {
//                    if find(package: pkg) == .none {
//                        add(package: pkg, queue: .upgrades)
//                    }
//                }
//            }
//
//            for tuple in savedInstalls {
//                let id = tuple.0
//                let version = tuple.1
//
//                if let pkg = plm.package(identifier: id, version: version) ?? plm.newestPackage(identifier: id, repoContext: nil) {
//                    if find(package: pkg) == .none {
//                        add(package: pkg, queue: .installations)
//                    }
//                }
//            }
//        }
        
        // Check for essential
        var allowedHosts = [String]()
        #if targetEnvironment(macCatalyst)
        allowedHosts = ["apt.procurs.us"]
        #else
        if Jailbreak.bootstrap == .procursus {
            allowedHosts = ["apt.procurs.us", "roothide.github.io", "iosjb.top"]
        } else {
            allowedHosts = [
                "apt.bingner.com",
                "test.apt.bingner.com",
                "apt.elucubratus.com"
            ]
        }
        #endif
        let installedPackages = plm.installedPackages
        for repo in allowedHosts {
            if let repo = RepoManager.shared.repoList.first(where: { $0.url?.host == repo }) {
                for package in repo.packageArray where package.essential == "yes" &&
                                                            installedPackages[package.packageID] == nil &&
                                                            find(package: package) == .none {
                                                                if checkRootHide(package) {
                                                                    reloadNeeded = true
                                                                    add(package: package, queue: .installdeps)
                                                                }
                }
            }
        }
        // Don't bother to reloadData if there's nothing to reload, it's a waste of resources
        if reloadNeeded {
            reloadData(recheckPackages: true)
        }
    }
    
    public func isEssential(_ package: Package) -> Bool {
        // Check for essential
        var allowedHosts = [String]()
        #if targetEnvironment(macCatalyst)
        allowedHosts = ["apt.procurs.us"]
        #else
        if Jailbreak.bootstrap == .procursus {
            allowedHosts = ["apt.procurs.us"]
        } else {
            allowedHosts = [
                "apt.bingner.com",
                "test.apt.bingner.com",
                "apt.elucubratus.com"
            ]
        }
        #endif
        guard let sourceRepo = package.sourceRepo,
              allowedHosts.contains(sourceRepo.url?.host ?? "") else { return false }
        return package.essential == "yes"
    }
    
    public func performOperations(progressCallback: @escaping (Double, Bool, String, String) -> Void,
                                  outputCallback: @escaping (String, Int) -> Void,
                                  completionCallback: @escaping (Int, APTWrapper.FINISH, Bool) -> Void) {
        var installs = Array(installations.raw)
        installs += upgrades.raw
        let removals = Array(uninstallations.raw) + Array(uninstalldeps.raw)
        let installdeps = Array(installdeps.raw)
        APTWrapper.performOperations(installs: installs,
                                     removals: removals,
                                     installDeps: installdeps,
                                     progressCallback: progressCallback,
                                     outputCallback: outputCallback,
                                     completionCallback: completionCallback)
    }
}
