//
//  CustomVibraceFilter.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/18/25.
//


import CoreImage
import CoreImage.CIFilterBuiltins

class CustomVibraceFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?
    
    private static let kernel: CIColorKernel? = {
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
        return kernel
    }()
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        return CustomVibraceFilter.kernel?.apply(extent: inputImage.extent, arguments: [inputImage, 1.0])
    }
}
