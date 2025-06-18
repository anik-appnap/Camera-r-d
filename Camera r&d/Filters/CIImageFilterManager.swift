//
//  CIImageFilterManager.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/3/25.
//

import CoreImage.CIFilterBuiltins
import simd

class CIImageFilterManager {
    static let shared = CIImageFilterManager()
    
    // Preconfigure filters that require additional parameters
    private static func makeCrossPolynomialFilter() -> CIFilter {
        let crossPolynomial = CIFilter.colorCrossPolynomial()
        crossPolynomial.redCoefficients   = CIVector(values: [0, 0, 0, 0], count: 4)   // force zero
        crossPolynomial.greenCoefficients = CIVector(values: [0, 1, 0, 0], count: 4)   // keep green
        crossPolynomial.blueCoefficients  = CIVector(values: [0, 0, 0, 0], count: 4)   // use red as blue
        return crossPolynomial
    }
    
    
    let filters: [CIFilter]
    
    init() {
        // Preconfigured filters for those that need extra setup
        let crossPolynomial = Self.makeCrossPolynomialFilter()
        
        filters = [
            crossPolynomial,
            CIFilter.randomGenerator(),
            CIFilter.customFalseColorFilter(),
            CIFilter.customVibraceFilter(),
            CIFilter.glitchFilter(),
            CIFilter.colorInvert(),
            CIFilter.colorMap(),
            CIFilter.colorMonochrome(),
            CIFilter.colorPosterize(),
            CIFilter.falseColor(),
            CIFilter.maskToAlpha(),
            CIFilter.photoEffectChrome(),
            CIFilter.photoEffectFade(),
            CIFilter.photoEffectInstant(),
            CIFilter.photoEffectMono(),
            CIFilter.photoEffectNoir(),
            CIFilter.photoEffectProcess(),
            CIFilter.photoEffectTonal(),
            CIFilter.photoEffectTransfer(),
            CIFilter.sepiaTone(),
            CIFilter.vignette(),
            CIFilter.vignetteEffect(),
            CIFilter.vibrance() // newly added
        ]
        
        // Set default parameters for filters where necessary
        if let filter = filters.first(where: { $0.name == "CIColorMonochrome" }) as? CIColorMonochrome {
            filter.intensity = 1.0
            filter.color = CIColor(red: 0.7, green: 0.7, blue: 0.7)
        }
        
        if let filter = filters.first(where: { $0.name == "CIColorPosterize" }) as? CIColorPosterize {
            filter.levels = 6
        }
        
        if let filter = filters.first(where: { $0.name == "CIFalseColor" }) as? CIFalseColor {
            filter.color0 = CIColor.red
            filter.color1 = CIColor.blue
        }
        
        if let filter = filters.first(where: { $0.name == "CISepiaTone" }) as? CISepiaTone {
            filter.intensity = 1.0
        }
        
        if let filter = filters.first(where: { $0.name == "CIVignette" }) as? CIVignette {
            filter.intensity = 1.0
            filter.radius = 2.0
        }
        
        // Optionally, set a default value for CIFilter.vibrance()
        if let filter = filters.first(where: { $0.name == "CIVibrance" }) as? CIVibrance {
            filter.amount = 1.0
        }
    }
    
    
    func applyFilters(to image: CIImage, filter: CIFilter, val: Float) -> CIImage? {
        if filter.name == "CIRandomGenerator"{
            return applyTVFilter(on: image)
        }
        else{
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage
        }
    }
    
    
    func applyTVFilter(on image: CIImage)->CIImage?{
        let filter = CIFilter.sourceOverCompositing()
        let randomfilter = CIFilter.randomGenerator()
        
        let offsetX = CGFloat.random(in: 0...1000)
        let offsetY = CGFloat.random(in: 0...1000)
        let transform = CGAffineTransform(translationX: -offsetX, y: -offsetY)
        let shiftedImage = randomfilter.outputImage!.transformed(by: transform).cropped(to: CGRect(origin: .zero,
                                                                                                   size: CGSize(
                                                                                                    width: CGFloat.random(in: 100...300),
                                                                                                    height: CGFloat.random(in: 100...300))))
        
        let randoImage = shiftedImage.resizeCIImage(to: image.extent.size)
        filter.inputImage = randoImage
        
        filter.backgroundImage = image
        return filter.outputImage
    }
}
