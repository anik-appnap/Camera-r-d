//
//  MetalFilters.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/18/25.
//

import Foundation
import CoreImage

class MetalFilters{
    func leftSideTransparent(image: CIImage)->CIImage?{
        guard let metallibURL = Bundle.main.url(forResource: "Custom.ci", withExtension: "metallib") else {
            fatalError("Failed to load polar kernel")
        }
        do{
            let data = try Data(contentsOf: metallibURL)
            let kernel = try CIKernel( functionName: "makeLeftSideTransparent", fromMetalLibraryData: data)
            
            let arguments = [image, 0.5] as [Any]
            
            let outputImage = kernel.apply(extent: image.extent, roiCallback: { _, rect in
                return rect
            }, arguments: arguments)
            
            return outputImage
        }
        catch{
            print("🔴 \(error)")
            
            return nil
        }
    }
    
    func pixelated(image: CIImage)->CIImage?{
        guard let metallibURL = Bundle.main.url(forResource: "Custom.ci", withExtension: "metallib") else {
            fatalError("Failed to load polar kernel")
        }
        do{
            let data = try Data(contentsOf: metallibURL)
            let kernel = try CIKernel( functionName: "polarPixellateKernel", fromMetalLibraryData: data)
            
            let pixelSize = CIVector(x: 0.05, y: 0.03) // block size: angular and radial
            let center = CIVector(x: 0.35, y: 0.55)     // center of polar effect (normalized)
            
            let arguments: [Any] = [image, pixelSize, center]

            let outputImage = kernel.apply(
                extent: image.extent,
                roiCallback: { _, rect in rect },
                arguments: arguments
            )
            return outputImage
        }
        catch{
            print("🔴 \(error)")
            
            return nil
        }
    }
}
