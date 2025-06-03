//
//  CameraFilter.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/3/25.
//


import CoreImage.CIFilterBuiltins
import simd

public extension matrix_float4x4 {
    static let identity = matrix_float4x4(rows: [SIMD4<Float>(1, 0, 0, 0),
                                                 SIMD4<Float>(0, 1, 0, 0),
                                                 SIMD4<Float>(0, 0, 1, 0),
                                                 SIMD4<Float>(0, 0, 0, 1)])
}

// MARK: - Camera Filter Support

struct CameraFilter {
    let name: String
    let parameterKey: String
    let minValue: Float
    let maxValue: Float
    let defaultValue: Float
}

class CameraFilterManager {
    static let shared = CameraFilterManager()

    let filters: [CameraFilter] = [
        CameraFilter(name: "CIColorControls", parameterKey: kCIInputBrightnessKey, minValue: -1.0, maxValue: 1.0, defaultValue: 0.0),
        CameraFilter(name: "CIColorControls", parameterKey: kCIInputContrastKey, minValue: 0.25, maxValue: 4.0, defaultValue: 1.0),
        CameraFilter(name: "CIColorControls", parameterKey: kCIInputSaturationKey, minValue: 0.0, maxValue: 2.0, defaultValue: 1.0),
        CameraFilter(name: "CISepiaTone", parameterKey: kCIInputIntensityKey, minValue: 0.0, maxValue: 1.0, defaultValue: 1.0),
        CameraFilter(name: "CIVignette", parameterKey: kCIInputIntensityKey, minValue: 0.0, maxValue: 1.0, defaultValue: 0.0),
        CameraFilter(name: "CIVignette", parameterKey: kCIInputRadiusKey, minValue: 0.0, maxValue: 2.0, defaultValue: 1.0),
        CameraFilter(name: "CIGaussianBlur", parameterKey: kCIInputRadiusKey, minValue: 0.0, maxValue: 10.0, defaultValue: 10.0),
        CameraFilter(name: "CISharpenLuminance", parameterKey: kCIInputSharpnessKey, minValue: 0.0, maxValue: 2.0, defaultValue: 0.4),
        CameraFilter(name: "CIExposureAdjust", parameterKey: "inputEV", minValue: -10.0, maxValue: 10.0, defaultValue: 0.0),
        CameraFilter(name: "CIColorMonochrome", parameterKey: kCIInputIntensityKey, minValue: 0.0, maxValue: 1.0, defaultValue: 1.0),
        CameraFilter(name: "CIBloom", parameterKey: kCIInputIntensityKey, minValue: 0.0, maxValue: 1.0, defaultValue: 0.5),
        CameraFilter(name: "CIBloom", parameterKey: kCIInputRadiusKey, minValue: 0.0, maxValue: 100.0, defaultValue: 10.0),
    ]
    
    func apply(filter: CameraFilter, to image: CIImage, with value: Float) -> CIImage? {
        
        let filter1 = CIFilter.colorControls()
        filter1.inputImage = image
        filter1.contrast = 2.9
        
        let filter2 = CIFilter.highlightShadowAdjust()
        filter2.inputImage = filter1.outputImage
        filter2.highlightAmount = 0.3
        
        let filter3 = CIFilter.hueAdjust()
        filter3.inputImage = filter2.outputImage
        filter3.angle = 1.665 // * .pi
        
        let filter4 = CIFilter.vibrance()
        filter4.inputImage = filter3.outputImage
        filter4.amount = 0.8
        
        let filter5 = CIFilter.colorControls()
        filter5.inputImage = filter4.outputImage
        filter5.saturation = 0.96
                
        return filter5.outputImage//applyCrosshatchMetalFilter(to: image, spacing: 0.01, lineWidth: 0.003)
    }
    
    func applyColorMatrixFilter(to inputImage: CIImage,
                                intensity: Float,
                                context: CIContext = CIContext()) -> CIImage? {
        
        var matrix: matrix_float4x4 = .identity
        matrix[0][1] = 1
        matrix[2][1] = 1
        matrix[3][1] = 1
        
        // Convert matrix to CIVector format (column-major)
        let rVector = CIVector(x: CGFloat(matrix.columns.0.x), y: CGFloat(matrix.columns.0.y), z: CGFloat(matrix.columns.0.z), w: CGFloat(matrix.columns.0.w))
        let gVector = CIVector(x: CGFloat(matrix.columns.1.x), y: CGFloat(matrix.columns.1.y), z: CGFloat(matrix.columns.1.z), w: CGFloat(matrix.columns.1.w))
        let bVector = CIVector(x: CGFloat(matrix.columns.2.x), y: CGFloat(matrix.columns.2.y), z: CGFloat(matrix.columns.2.z), w: CGFloat(matrix.columns.2.w))
        let aVector = CIVector(x: CGFloat(matrix.columns.3.x), y: CGFloat(matrix.columns.3.y), z: CGFloat(matrix.columns.3.z), w: CGFloat(matrix.columns.3.w))

        let colorMatrixFilter = CIFilter.colorMatrix()
        colorMatrixFilter.inputImage = inputImage
        colorMatrixFilter.rVector = rVector
        colorMatrixFilter.gVector = gVector
        colorMatrixFilter.bVector = bVector
        colorMatrixFilter.aVector = aVector

        guard let filteredImage = colorMatrixFilter.outputImage else {
            return nil
        }

        // Blend original and filtered image using intensity (lerp)
        let blendFilter = CIFilter.blendWithAlphaMask()
        blendFilter.inputImage = filteredImage
        blendFilter.backgroundImage = inputImage

        // Create a grayscale alpha mask from intensity
        let mask = CIFilter(name: "CIConstantColorGenerator")!
        mask.setValue(CIColor(red: CGFloat(intensity), green: CGFloat(intensity), blue: CGFloat(intensity), alpha: CGFloat(intensity)), forKey: kCIInputColorKey)
        blendFilter.maskImage = mask.outputImage?.cropped(to: inputImage.extent)

        return blendFilter.outputImage
    }
    
    
    func applyCrosshatchMetalFilter(to image: CIImage, spacing: Float, lineWidth: Float) -> CIImage? {
        guard let metallibURL = Bundle.main.url(forResource: "default", withExtension: "metallib"),
              let data = try? Data(contentsOf: metallibURL),
              let kernel = try? CIKernel(functionName: "crosshatchFilterCIKernel", fromMetalLibraryData: data)
        else {
            print("❌ Failed to load Metal kernel")
            return nil
        }

        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in rect },
            arguments: [image, spacing, lineWidth]
        )
    }
    
}
