//  Created by Andromeda on 01/10/2021.
//

import Foundation

public extension FileManager {
    func directorySize(_ dir: URL) -> Int {
        guard let enumerator = self.enumerator(at: dir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { return 0 }
        var bytes = 0
        for case let url as URL in enumerator {
            bytes += Int(url.size)
        }
        return bytes
    }
    
    func sizeString(_ dir: URL) -> String {
        let bytes = directorySize(dir)
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    var documentDirectory: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
