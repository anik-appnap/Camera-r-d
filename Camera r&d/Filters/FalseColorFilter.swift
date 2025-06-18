//
//  FalseColorFilter.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/18/25.
//


import CoreImage
import CoreImage.CIFilterBuiltins

class FalseColorFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    
    private static let kernel: CIColorKernel = {
        let falseColorKernelCode = """
        kernel vec4 falseColor(__sample image, vec3 firstColor, vec3 secondColor) {
            float luminance = dot(image.rgb, vec3(0.2126, 0.7152, 0.0722));
            vec3 color = mix(firstColor, secondColor, luminance);
            return vec4(color, image.a);
        }
        """
        return CIColorKernel(source: falseColorKernelCode)!
    }()
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        return FalseColorFilter.kernel.apply(extent: inputImage.extent, arguments:
                                                [inputImage,
                                                 CIVector(x: 1, y: 0, z: 0),
                                                 CIVector(x: 0, y: 0, z: 1)])
    }
}

