//
//  GlitchFilter.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/18/25.
//


import CoreImage
import CoreImage.CIFilterBuiltins

class GlitchFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    
    override var outputImage: CIImage? {
        guard let image = inputImage else{return nil}
        guard let url = Bundle.main.url(forResource: "glitch", withExtension: "png") else{return nil}
        let glitchImage =  CIImage(contentsOf: url)!
        let filter = CIFilter.sourceOverCompositing()
        let scaledImage = glitchImage.resizeCIImage(to: image.extent.size)?.applyOffset(
            offset: CGPoint(x: CGFloat.random(in: -50...50),
                            y: CGFloat.random(in: -50...50)))
            .setOpacity(alpha: 0.7)
        filter.inputImage = scaledImage
        filter.backgroundImage = image
        
        let output = filter.outputImage?.cropped(to: image.extent)
        return output
    }
}
