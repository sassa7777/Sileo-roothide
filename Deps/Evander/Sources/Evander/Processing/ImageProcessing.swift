//  Created by Amy While on 16/02/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import UIKit

final public class ImageProcessing {
    
    public class func downsample(image: UIImage, to pointSize: CGSize? = nil, scale: CGFloat? = nil) -> UIImage? {
        let size = pointSize ?? image.size
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let data = image.pngData() as CFData?,
              let imageSource = CGImageSourceCreateWithData(data, imageSourceOptions) else { return nil }
        return downsample(source: imageSource, size: size, scale: scale)
    }
    
    public class func downsample(url: URL, to pointSize: CGSize? = nil, scale: CGFloat? = nil) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions),
              let size = pointSize ?? getSize(from: imageSource) else {
            return nil
        }
        return downsample(source: imageSource, size: size, scale: scale)
    }
    
    private class func downsample(source: CGImageSource, size: CGSize, scale: CGFloat?) -> UIImage? {
        let maxDimentionInPixels = max(size.width, size.height) * (scale ?? UIScreen.main.scale)
        let downsampledOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceShouldCacheImmediately: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maxDimentionInPixels] as CFDictionary
        guard let downScaledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampledOptions) else { return nil }
        return UIImage(cgImage: downScaledImage)
    }
    
    private class func getSize(from source: CGImageSource) -> CGSize? {
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil),
              let height = (metadata as NSDictionary)["PixelHeight"] as? Double,
              let width = (metadata as NSDictionary)["PixelWidth"] as? Double else { return nil }
        return CGSize(width: width, height: height)
    }
    
}

final public class EvanderGIF: UIImage {
    public var calculatedDuration: Double?
    public var animatedImages: [UIImage]?

    convenience init?(data: Data, size: CGSize? = nil, scale: CGFloat? = nil) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil),
        let delayTime = ((metadata as NSDictionary)["{GIF}"] as? NSMutableDictionary)?["DelayTime"] as? Double else { return nil }
        var images = [UIImage]()
        let imageCount = CGImageSourceGetCount(source)
        for i in 0 ..< imageCount {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let tmpImage = UIImage(cgImage: image)
                if let downscaled = ImageProcessing.downsample(image: tmpImage, to: size, scale: scale) {
                    images.append(downscaled)
                } else {
                    images.append(tmpImage)
                }
            }
        }
        let calculatedDuration = Double(imageCount) * delayTime
        self.init()
        self.animatedImages = images
        self.calculatedDuration = calculatedDuration
    }
}


