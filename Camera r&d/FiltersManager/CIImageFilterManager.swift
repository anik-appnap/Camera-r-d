//
//  CIImageFilterManager.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/3/25.
//

import CoreImage.CIFilterBuiltins
import AVFoundation

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
        
        // Distortion Effect filters (CICategoryDistortionEffect)
        let bumpDistortion = CIFilter.bumpDistortion()
        bumpDistortion.radius = 300
        bumpDistortion.scale = 0.5
        bumpDistortion.center = CGPoint(x: 150, y: 150)

        let bumpDistortionLinear = CIFilter.bumpDistortionLinear()
        bumpDistortionLinear.radius = 300
        bumpDistortionLinear.scale = 0.5
        bumpDistortionLinear.center = CGPoint(x: 150, y: 150)

        let circleSplashDistortion = CIFilter.circleSplashDistortion()
        circleSplashDistortion.radius = 200

        let circularWrap = CIFilter.circularWrap()
        circularWrap.radius = 150
        circularWrap.center = CGPoint(x: 150, y: 150)

        let glassDistortion = CIFilter.glassDistortion()
        glassDistortion.center = CGPoint(x: 150, y: 150)
        glassDistortion.scale = 500

        let glassLozenge = CIFilter.glassLozenge()
        glassLozenge.point0 = CGPoint(x: 100, y: 100)
        glassLozenge.point1 = CGPoint(x: 300, y: 300)
        glassLozenge.radius = 100

        let pinchDistortion = CIFilter.pinchDistortion()
        pinchDistortion.radius = 300
        pinchDistortion.scale = 0.5
        pinchDistortion.center = CGPoint(x: 150, y: 150)

        let stretchCrop = CIFilter.stretchCrop()
        stretchCrop.size = CGPoint(x: 300, y: 300)
        stretchCrop.cropAmount = 0.25
        stretchCrop.centerStretchAmount = 0.25

        let torusLensDistortion = CIFilter.torusLensDistortion()
        torusLensDistortion.radius = 160
        torusLensDistortion.width = 80
        torusLensDistortion.center = CGPoint(x: 150, y: 150)

        let twirlDistortion = CIFilter.twirlDistortion()
        twirlDistortion.radius = 200
        twirlDistortion.angle = 3.14

        
        let vortexDistortion = CIFilter.vortexDistortion()
        vortexDistortion.radius = 200
        vortexDistortion.angle = 3.14
        vortexDistortion.center = CGPoint(x: 500, y: 500)
        
        let displaceDistortion = CIFilter.displacementDistortion()
        displaceDistortion.scale = 100
        
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
            CIFilter.vibrance(), // newly added
            // Distortion Effect filters
            bumpDistortion,
            bumpDistortionLinear,
            circleSplashDistortion,
            circularWrap,
            glassLozenge,
            pinchDistortion,
            stretchCrop,
            torusLensDistortion,
            twirlDistortion,
            vortexDistortion,
            displaceDistortion,
            glassDistortion,
            CIFilter.triangleTile(),
            CIFilter.perspectiveTile(),
            CIFilter.pointillize(),
            CIFilter.pixellate(),
            CIFilter.motionBlur(),
            CIFilter.perspectiveTransform(),
            CIFilter.photoEffectTransfer()
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
        else if filter.name == "CIGlassDistortion"{
            filter.setValue(image, forKey: kCIInputImageKey)
            let randomNoiseImage = generateRandomImage(isRandom: false)
            filter.setValue(randomNoiseImage.cropped(to: image.extent), forKey: "inputTexture")
        }
        else if filter.name == "CIDisplacementDistortion"{
            filter.setValue(image, forKey: kCIInputImageKey)
            let checkboardImage = getCheckboardImage(with: image.extent)
            filter.setValue(checkboardImage, forKey: "inputDisplacementImage")
        }
        else if filter.name == "CICircleSplashDistortion" {
            filter.setValue(image, forKey: kCIInputImageKey)
            if let faceFeature = detectFaces(in: image) {
                let center = CIVector(x: faceFeature.bounds.midX, y: faceFeature.bounds.midY)
                filter.setValue(center, forKey: kCIInputCenterKey)
            }
        }
        else if filter.name == "CITwirlDistortion"{
            filter.setValue(image, forKey: kCIInputImageKey)
            if let faceFeature = detectFaces(in: image) {
                let center = CIVector(x: faceFeature.bounds.midX, y: faceFeature.bounds.midY)
                filter.setValue(center, forKey: kCIInputCenterKey)
            }
        }
        else{
            filter.setValue(image, forKey: kCIInputImageKey)
        }
        return filter.outputImage?.cropped(to: image.extent)
    }
    
    func detectFaces(in ciImage: CIImage) -> CIFaceFeature? {
        let options: [String: Any] = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: options)!
        let feature = detector.features(in: ciImage).first as? CIFaceFeature
        return feature
    }
    
    func getCheckboardImage(with extent: CGRect)-> CIImage?{
        let checkboardFilter = CIFilter.checkerboardGenerator()
        checkboardFilter.color0 = .white
        checkboardFilter.color1 = .black
        return checkboardFilter.outputImage?.cropped(to: extent)
    }
    
    func generateRandomImage(isRandom: Bool = true)->CIImage{
        let randomfilter = CIFilter.randomGenerator()
        
        let offset = isRandom ? CGFloat.random(in: 0...1000) : 100
        let transform = CGAffineTransform(translationX: -offset, y: -offset)
        let scale = isRandom ? CGFloat.random(in: 100...300) : 100
        let shiftedImage = randomfilter.outputImage!.transformed(by: transform).cropped(to: CGRect(origin: .zero,
                                                                                                   size: CGSize(
                                                                                                    width: scale,
                                                                                                    height: scale)))
        return shiftedImage
    }
    
    func textImage(inputText: String) -> CIImage {
        let textImageGenerator = CIFilter.textImageGenerator()
        textImageGenerator.text = inputText
        textImageGenerator.fontName = "Helvetica"
        textImageGenerator.fontSize = 25
        textImageGenerator.scaleFactor = 4
        return textImageGenerator.outputImage!
    }
    
    func applyTVFilter(on image: CIImage)->CIImage?{
        let filter = CIFilter.sourceOverCompositing()
        
        let randoImage = generateRandomImage().resizeCIImage(to: image.extent.size)?.setOpacity(alpha: 0.5)
        filter.inputImage = randoImage
        
        filter.backgroundImage = image
        return filter.outputImage
    }
    
    func applyOverlayFilter(){
        let overlayURL = Bundle.main.url(forResource: "overlayVideo", withExtension: "mp4")!
        let overlayAsset = AVAsset(url: overlayURL)
        let overlayItem = AVPlayerItem(asset: overlayAsset)
        let overlayPlayer = AVPlayer(playerItem: overlayItem)

        let videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ])
        overlayItem.add(videoOutput)

        overlayPlayer.play()
        // Looping
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: overlayItem, queue: .main) { _ in
            overlayPlayer.seek(to: .zero)
            overlayPlayer.play()
        }
    }
}
