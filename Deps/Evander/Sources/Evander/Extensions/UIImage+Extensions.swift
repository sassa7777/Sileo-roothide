//  Created by Andromeda on 01/10/2021.
//

import UIKit

public extension UIImage {
    
    func resized(to size: CGSize) -> UIImage {
        if let animated = self as? EvanderGIF {
            var images = animated.animatedImages ?? []
            for (index, image) in (animated.animatedImages ?? []).enumerated() {
                images[index] = image.resized(to: size)
            }
            animated.animatedImages = images
            return animated
        }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func prepareForDisplay() -> UIImage {
        ImageProcessing.downsample(image: self) ?? self
    }
        
    convenience init?(systemNameOrNil name: String) {
        if #available(iOS 13.0, *) {
            self.init(systemName: name)
        } else {
            return nil
        }
    }
}
