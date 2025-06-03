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
        
//        filter.setValue(image, forKey: kCIInputImageKey)
//        return filter.outputImage
        
        let vibranceKernelSource = """
        kernel vec4 vibranceFilter(__sample image, float vibrance) {
            float average = (image.r + image.g + image.b) / 3.0;
            float mx = max(max(image.r, image.g), image.b);
            float amt = (mx - average) * (-vibrance * 3.0);
            vec3 adjusted = mix(image.rgb, vec3(mx), amt);
            return vec4(adjusted, image.a);
        }
        """
        
        guard let kernel = try? CIColorKernel(source: vibranceKernelSource) else {
                print("❌ Failed to compile vibrance kernel")
                return nil
            }
        
        let falseColorKernelCode = """
        kernel vec4 falseColor(__sample image, vec3 firstColor, vec3 secondColor) {
            float luminance = dot(image.rgb, vec3(0.2126, 0.7152, 0.0722));
            vec3 color = mix(firstColor, secondColor, luminance);
            return vec4(color, image.a);
        }
        """
        
        guard let falseColorKernel = try? CIColorKernel(source: falseColorKernelCode) else {
                print("❌ Failed to compile vibrance kernel")
                return nil
            }
        
        return falseColorKernel.apply(extent: image.extent, arguments: [image,CIVector(x: 1, y: 0, z: 0), CIVector(x: 0, y: 0, z: 1)])
    }
}
