//  Created by Amy on 01/05/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import Foundation


public class EvanderDownloadContainer {
    public var progress = DownloadProgress()
    public var progressCallback: ((_ task : EvanderDownloader, _ progress: DownloadProgress) -> Void)?
    public var didFinishCallback: ((_ task : EvanderDownloader, _ status: Int, _ url: URL) -> Void)?
    public var errorCallback: ((_ task : EvanderDownloader, _ status: Int, _ error: Error?, _ url: URL?) -> Void)?
    public var waitingCallback: ((_ task : EvanderDownloader, _ message: String) -> Void)?
    public init() {}
}

public struct DownloadProgress {
    public var period: Int64 = 0
    public var total: Int64 = 0
    public var expected: Int64 = 0
    public var fractionCompleted: Double {
        if expected==NSURLSessionTransferSizeUnknown || expected==0 {
            return 0
        } else {
            return Double(total) / Double(expected)
        }
    }
}

final public class EvanderDownloader: NSObject {
    
    static public var timeoutInterval:Double = 30
    
    static let sessionManager: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutInterval
        return URLSession(configuration: configuration, delegate: EvanderDownloadDelegate.shared, delegateQueue: OperationQueue())
    }()
    
    static let config = URLSessionConfiguration.default
    
    private var request: URLRequest
    private var task: URLSessionDownloadTask?
    public var container = EvanderDownloadContainer()
    
    public var progressCallback: ((_ task : EvanderDownloader, _ progress: DownloadProgress) -> Void)? {
        didSet {
            self.container.progressCallback = progressCallback
        }
    }
    public var didFinishCallback: ((_ task : EvanderDownloader, _ status: Int, _ url: URL) -> Void)? {
        didSet {
            self.container.didFinishCallback = didFinishCallback
        }
    }
    public var errorCallback: ((_ task : EvanderDownloader, _ status: Int, _ error: Error?, _ url: URL?) -> Void)? {
        didSet {
            self.container.errorCallback = errorCallback
        }
    }
    public var waitingCallback: ((_ task : EvanderDownloader, _ message: String) -> Void)? {
        didSet {
            self.container.waitingCallback = waitingCallback
        }
    }

    public init(url: URL, method: String = "GET", headers: [String: String] = [:]) {
        var request = URLRequest(url: url, timeoutInterval: EvanderDownloader.timeoutInterval)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        self.request = request
        super.init()
    }
    
    public init?(request: URLRequest) {
        self.request = request
        super.init()
    }
    
    deinit {
        NSLog("SileoLog: DownloadProgress deinit \(self.request)")
        self.cancel()
    }
    
    public func cancel() {
        NSLog("SileoLog: cancel task=\(self.task?.taskIdentifier) url=\(self.request.url)")
        if let task = self.task {
            EvanderDownloadDelegate.shared.sessions.removeValue(forKey: task)
        }
        //then
        task?.cancel()
    }
    
    public func resume() {
        task?.resume()
    }

    public func make() {
        let task = EvanderDownloader.sessionManager.downloadTask(with: request)
        NSLog("SileoLog: start downloadTask=\(task.taskIdentifier) url=\(self.request.url)")
        EvanderDownloadDelegate.shared.sessions[task] = self
        self.task = task
    }
    
}

final public class EvanderDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    static public let shared = EvanderDownloadDelegate()
    
    private let queueKey = DispatchSpecificKey<Int>()
    public let queueContext = 50
    
    public lazy var sessions: SafeDictionary = SafeDictionary<URLSessionTask, EvanderDownloader>(queue: queue, key: queueKey, context: queueContext)
    
    private lazy var queue: DispatchQueue = {
        let queue = DispatchQueue(label: "AmyDownloadParserDelegate.ContainerQueue")
        queue.setSpecific(key: queueKey, value: queueContext)
        return queue
    }()
    
    // The Download Finished
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        NSLog("SileoLog: didFinishDownloadingTo \(downloadTask.response?.url) task=\(downloadTask.taskIdentifier) url=\(location) response=\(downloadTask.response)")
        
        guard let downloader = self.sessions[downloadTask] else { return }

        let filename = location.lastPathComponent,
            destination = EvanderNetworking.downloadCache.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            if !EvanderNetworking.downloadCache.dirExists {
                try FileManager.default.createDirectory(at: EvanderNetworking.downloadCache, withIntermediateDirectories: true)
            }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            downloader.container.errorCallback?(downloader, 522, error, destination)
        }

        if let response = downloadTask.response,
           let statusCode = (response as? HTTPURLResponse)?.statusCode {
            if statusCode == 200 || statusCode == 206 { // 206 means partial data, APT handles it fine
                downloader.container.didFinishCallback?(downloader, statusCode, destination)
            } else {
                downloader.container.errorCallback?(downloader, statusCode, nil, destination)
            }
            return
        }
    }
    
    // The Download has made Progress
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {        NSLog("SileoLog: didWriteData task=\(downloadTask.taskIdentifier)  (\(totalBytesWritten)+\(bytesWritten)/\(totalBytesExpectedToWrite)) \(downloadTask.response)") //totalBytesExpectedToWrite may be -1, no 'Content Length'? or 404
        guard let downloader = self.sessions[downloadTask] else { return }
        if (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 {
            downloader.container.progress.period = bytesWritten
            downloader.container.progress.total = totalBytesWritten
            downloader.container.progress.expected = totalBytesExpectedToWrite
            downloader.container.progressCallback?(downloader, downloader.container.progress)
        }
    }
    
    // Checking for errors in the download
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NSLog("SileoLog: didCompleteWithError task=\(task.taskIdentifier) status=\((task.response as? HTTPURLResponse)?.statusCode) \nresp=\(task.response?.url) \nreq=\(task.currentRequest?.url) error=\n\(error)")
        
        guard let downloader = self.sessions[task] else { return }
        
        //timeout: error!=nil, task.response=nil or statusCode=200
        
        if let error = error {
            let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? 522
            downloader.container.errorCallback?(sessions[task]!, statusCode, error, nil)
        }
        
        //canceled or completed
        if (task.response as? HTTPURLResponse)?.statusCode == 200 {
            self.sessions.removeValue(forKey: task)
            return
        }
    }
    
    // Tell the caller that the download is waiting for network
    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        NSLog("SileoLog: taskIsWaitingForConnectivity \(session) task=\(task.taskIdentifier)")
        guard let downloader = self.sessions[task] else { return }
        downloader.container.waitingCallback?(sessions[task]!, "Waiting For Connection")
    }
    
    // The Download started again with some progress
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        NSLog("SileoLog: didResumeAtOffset \(session) task=\(downloadTask.taskIdentifier)")
        guard let downloader = self.sessions[downloadTask] else { return }
        downloader.container.progress.period = 0
        downloader.container.progress.total = fileOffset
        downloader.container.progress.expected = expectedTotalBytes
        downloader.container.progressCallback?(downloader, downloader.container.progress)
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        NSLog("SileoLog: willPerformHTTPRedirection \(session) task=\(task.taskIdentifier)\n\(response.url)\n\(request.url)")
        completionHandler(request)
    }
}
