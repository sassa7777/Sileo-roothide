//  Created by Andromeda on 01/10/2021.
//

import Foundation
import Darwin

public extension URL {
    
    private static let S_IFLNK: Int = 0o120000
    private static let S_IFMT : Int = 0o170000
    private static let S_IFDIR: Int = 0o040000
    
    var size: Int64 {
        var sb = stat()
        return stat(path, &sb) == 0 ? sb.st_size : 0
    }

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var creationDate: Date? {
        var sb = stat()
        return stat(path, &sb) == 0 ? Date(timespec: sb.st_birthtimespec) : nil
    }
    
    var modificationDate: Date? {
        var sb = stat()
        return stat(path, &sb) == 0 ? Date(timespec: sb.st_mtimespec) : nil
    }
    
    var statusDate: Date? {
        var sb = stat()
        return stat(path, &sb) == 0 ? Date(timespec: sb.st_ctimespec) : nil
    }
    
    var symlink: Bool {
        var sb = stat()
        return stat(path, &sb) == 0 && (Int(sb.st_mode) & Self.S_IFMT) == Self.S_IFLNK
    }
    
    var exists: Bool {
        access(path, F_OK) == 0
    }
    
    var dirExists: Bool {
        var sb = stat()
        return stat(path, &sb) == 0 && (Int(sb.st_mode) & Self.S_IFMT) == Self.S_IFDIR
    }

    func contents() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
    }
    

    var implicitContents: [URL] {
        (try? contents()) ?? []
    }
}
