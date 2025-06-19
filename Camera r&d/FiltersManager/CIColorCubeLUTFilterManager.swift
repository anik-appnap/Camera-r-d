//
//  CIColorCubeLUTFilterManager.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/19/25.
//


import CoreImage
import UIKit

class LUTParserManager {
    static let shared = LUTParserManager()
    
    private init() {}
    
    func parseCubeLUT(from url: URL) -> (Int, Data)? {
        guard let content = try? String(contentsOf: url) else { return nil }
        
        var cubeValues = [Float]()
        var dimension = 0
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue // Skip comments and empty lines
            }
            
            if trimmed.uppercased().hasPrefix("LUT_3D_SIZE") {
                let comps = trimmed.components(separatedBy: .whitespaces)
                if let dim = Int(comps.last ?? "") {
                    dimension = dim
                }
            } else if trimmed.range(of: #"^([0-9.]+\s+){2}[0-9.]+$"#, options: .regularExpression) != nil {
                let comps = trimmed.split(separator: " ").compactMap { Float($0) }
                if comps.count == 3 {
                    cubeValues.append(contentsOf: comps + [1.0]) // Add alpha
                }
            }
        }
        
        let expectedCount = dimension * dimension * dimension * 4
        guard cubeValues.count == expectedCount else {
            print("❌ Data count mismatch: expected \(expectedCount), got \(cubeValues.count)")
            return nil
        }
        
        return (dimension, Data(buffer: UnsafeBufferPointer(start: cubeValues, count: cubeValues.count)))
    }
}
