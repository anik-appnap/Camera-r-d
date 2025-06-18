//
//  CoreImage+Extension.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/17/25.
//

import CoreImage

extension CIImage{
    func setOpacity (alpha : Double) ->CIImage {
        let image = self
        guard let overlayFilter: CIFilter = CIFilter(name: "CIColorMatrix") else { fatalError() }
        let overlayRgba: [CGFloat] = [0, 0, 0, alpha]
        let alphaVector: CIVector = CIVector(values: overlayRgba, count: 4)
        overlayFilter.setValue(image, forKey: kCIInputImageKey)
        overlayFilter.setValue(alphaVector, forKey: "inputAVector")
        
        return overlayFilter.outputImage!
    }
    
    func resizeCIImage(to size: CGSize) -> CIImage? {
        let image = self
        let scaleX = size.width / image.extent.width
        let scaleY = size.height / image.extent.height
        return image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
    
    func applyOffset(offset: CGPoint) -> CIImage {
        let image = self
        return image.transformed(by: CGAffineTransform(translationX: offset.x, y: offset.y))
    }
}

extension CIFilter{
    public class func customFalseColorFilter()->CIFilter{
        return FalseColorFilter()
    }
    
    public class func customVibraceFilter()->CIFilter{
        return CustomVibraceFilter()
    }
    
    public class func glitchFilter()->CIFilter{
        return GlitchFilter()
    }
}
