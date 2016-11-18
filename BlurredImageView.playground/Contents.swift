import UIKit
import Accelerate
import PlaygroundSupport

class BlurredImageView: UIImageView {
    
    private var original: UIImage?
    private var originalHighlighted: UIImage?
    
    override init(image: UIImage?) {
        super.init(image: image)
        original = image
    }
    
    override init(image: UIImage?, highlightedImage: UIImage?) {
        super.init(image: image, highlightedImage: highlightedImage)
        original = image
        originalHighlighted = highlightedImage
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var blurRadius: CGFloat = 0 {
        didSet {
            if blurRadius <= 0 { return }
            updateBlur(forRadius: blurRadius)
        }
    }
    
    func updateBlur(forRadius radius: CGFloat) {
        image = original?.vImage_blur(radius: radius)
        highlightedImage = originalHighlighted?.vImage_blur(radius: radius)
    }
    
}


extension CGContext {
    func toBuffer() -> vImage_Buffer {
        return vImage_Buffer(
            data: data,
            height: UInt(height),
            width: UInt(width),
            rowBytes: bytesPerRow
        )
    }
}

extension UIImage {
    
    func vImage_blur(radius: CGFloat) -> UIImage? {
        let imageRect = CGRect(origin: .zero, size: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        
        guard let effectInContext = UIGraphicsGetCurrentContext() else { return nil }
        effectInContext.scaleBy(x: 1, y: -1)
        effectInContext.translateBy(x: 0, y: -size.height)
        effectInContext.draw(cgImage!, in: imageRect)
        
        var effectInBufer = effectInContext.toBuffer()
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let effectOutContext = UIGraphicsGetCurrentContext() else { return nil }
        
        var effectOutBuffer = effectOutContext.toBuffer()
        
        let inputRadius = radius * UIScreen.main.scale
        
        var radius = floor(Double(inputRadius) * 3 * sqrt(2 * .pi) / 4 + 0.5)
        
        if radius.truncatingRemainder(dividingBy: 2) != 1 { // modulus
            radius += 1 // forces odd number for the following box convolution
        }
        
        var backgroundColor: UInt8 = 0
        
        vImageBoxConvolve_ARGB8888(
            &effectInBufer,
            &effectOutBuffer,
            nil,
            0,
            0,
            UInt32(radius),
            UInt32(radius),
            &backgroundColor,
            UInt32(kvImageEdgeExtend)
        )
        
        // swap buffers
        
        vImageBoxConvolve_ARGB8888(
            &effectOutBuffer,
            &effectInBufer,
            nil,
            0,
            0,
            UInt32(radius),
            UInt32(radius),
            &backgroundColor,
            UInt32(kvImageEdgeExtend)
        )
        
        // swap back
        
        vImageBoxConvolve_ARGB8888(
            &effectInBufer,
            &effectOutBuffer,
            nil,
            0,
            0,
            UInt32(radius),
            UInt32(radius),
            &backgroundColor,
            UInt32(kvImageEdgeExtend)
        )
        
        let effectImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let outputContext = UIGraphicsGetCurrentContext() else { return nil }
        outputContext.scaleBy(x: 1, y: -1)
        outputContext.translateBy(x: 0, y: -size.height)
        outputContext.draw(cgImage!, in: imageRect)
        
        
        outputContext.saveGState()
        outputContext.draw(effectImage!.cgImage!, in: imageRect)
        outputContext.restoreGState()
        
        let outputImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return outputImage
    }
    
}

let image = #imageLiteral(resourceName: "earth-image.png")

let imageView = BlurredImageView(image: image)
imageView.blurRadius = 0

PlaygroundPage.current.liveView = imageView