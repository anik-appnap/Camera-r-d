//
//  CameraViewController.swift
//  Camera r&d
//
//  Created by Appnap WS05 on 6/2/25.
//

import UIKit
import PhotosUI
import AVFoundation
import MetalKit
import CoreImage
import CoreImage.CIFilterBuiltins

protocol cameraDelegate: AnyObject{
    func capture(texture: MTLTexture?)
}

extension AVCaptureDevice.Position{
    var toggle: AVCaptureDevice.Position{
        if self == .back{
            return .front
        }
        else{
            return .back
        }
    }
}

enum MediaType{
    case video
    case photo
}

class CameraViewController: UIViewController, FilterSelectionViewDelegate, PHPickerViewControllerDelegate {
    // Video recording state properties
    var assetWriter: AVAssetWriter?
    var videoInput: AVAssetWriterInput?
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    var isRecording = false
    var recordingStartTime: CMTime?
    var hasStartedSession = false
    
    // AV Foundation
    let captureSession = AVCaptureSession()
    let cameraHolderView: UIView = {
        let view = UIView()
        return view
    }()
    let cameraView = MTKView()
    var cameraFrameAdded = false
    var currentCameraPosition: AVCaptureDevice.Position = .front
    
    // overlay view
    var overlayPlayer: AVPlayer?
    var overlayVideoOutput: AVPlayerItemVideoOutput?
    
    //photo picker
    var hasMediaPickedFromGallery: Bool = false
    var mediaType: MediaType? = .none
    var originalSelectedImage: CIImage? = nil
    
    public var metalDevice: MTLDevice!
    public var metalCommandQueue: MTLCommandQueue!
    public var ciContext: CIContext!
    
    weak var delegate: cameraDelegate?
    var selectedFilterModel: CameraFilter?
    var selectedFilter: CIFilter?
    
    let switchButton = UIButton(type: .system)
    let intensitySlider = UISlider()
    let photoCaptureButton = UIButton(type: .system)
    let videoCaptureButton = UIButton(type: .system)
    let filtersListView = FilterSelectionView()
    
    public var currentCIImage: CIImage? {
        didSet {
            cameraView.draw()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraView()
        setupMetal()
        setupCoreImage()
        setupSession()
        setupExtraUIConponents()
        
        filtersListView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !cameraFrameAdded {
            cameraView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            cameraView.isOpaque = false
            cameraHolderView.addSubview(cameraView)
            cameraView.fillSuperview()
            cameraFrameAdded.toggle()
        }
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        stopSession()
        super.viewWillDisappear(animated)
    }
    
    func setupCameraView(){
        view.addSubview(cameraHolderView)
        cameraHolderView.anchorView(top: view.safeAreaLayoutGuide.topAnchor,
                                    left: view.leftAnchor,
                                    right: view.rightAnchor)
        cameraHolderView.setDimesion(height: 500)
    }
    
    func setupExtraUIConponents(){
        //camera switch
        switchButton.setImage(.init(systemName: "arrow.triangle.2.circlepath.camera.fill"), for: .normal)
        switchButton.addTarget(self, action: #selector(showCameraSelection), for: .touchUpInside)
        view.addSubview(switchButton)
        switchButton.anchorView(top: cameraHolderView.bottomAnchor, paddingTop: 20)
        switchButton.centerAnchor(x: view)
        
        //filter intensity slider
        view.addSubview(intensitySlider)
        intensitySlider.anchorView(top: switchButton.bottomAnchor, left: view.leftAnchor, right: view.rightAnchor, paddingTop: 20, paddingLeft: 20, paddingRight: 20)
        
        //filters list view
        view.addSubview(filtersListView)
        filtersListView.anchorView(top: intensitySlider.bottomAnchor, left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor)
        
        //capture buttons
        photoCaptureButton.setTitle("Capture Photo", for: .normal)
        photoCaptureButton.setImage(.init(systemName: "camera.fill"), for: .normal)
        photoCaptureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(photoCaptureButton)
        photoCaptureButton.anchorView(top: cameraHolderView.bottomAnchor, left: cameraHolderView.leftAnchor, paddingTop: 20, paddingLeft: 20)
        
        videoCaptureButton.setTitle("Record Video", for: .normal)
        videoCaptureButton.setImage(.init(systemName: "video.fill"), for: .normal)
        videoCaptureButton.addTarget(self, action: #selector(recordVideo), for: .touchUpInside)
        view.addSubview(videoCaptureButton)
        videoCaptureButton.anchorView(top: cameraHolderView.bottomAnchor, right: cameraHolderView.rightAnchor, paddingTop: 20, paddingRight: 20)
    }
    
    func setupSession() {
        captureSession.beginConfiguration()
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("Error setting device input: \(error)")
            return
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.queue"))
        captureSession.addOutput(output)
        output.connections.first?.videoOrientation = .portrait
        output.connections.first?.isVideoMirrored = true
        
        captureSession.commitConfiguration()
    }
    
    func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        metalCommandQueue = metalDevice.makeCommandQueue()
        cameraView.device = metalDevice
        cameraView.isPaused = true
        cameraView.enableSetNeedsDisplay = false
        cameraView.delegate = self
        cameraView.framebufferOnly = false
    }
    
    func setupCoreImage() {
        ciContext = CIContext(mtlDevice: metalDevice)
    }
    
    @objc func showCameraSelection() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInTripleCamera
            ],
            mediaType: .video,
            position: .unspecified
        )

        let cameras = discovery.devices
        let alert = UIAlertController(title: "Select Camera", message: nil, preferredStyle: .actionSheet)

        for device in cameras {
            let name = "\(device.localizedName) (\(device.position == .front ? "Front" : "Back"))"
            alert.addAction(UIAlertAction(title: name, style: .default, handler: { _ in
                self.switchToCamera(device: device)
            }))
        }

        alert.addAction(UIAlertAction(title: "Choose from Photo Library", style: .default, handler: { _ in
            self.stopSession()
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            self.present(picker, animated: true)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func switchToCamera(device: AVCaptureDevice) {
        hasMediaPickedFromGallery = false
        captureSession.beginConfiguration()

        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
            }
            currentCameraPosition = device.position
        } catch {
            print("Failed to switch camera: \(error)")
        }

        if let connection = captureSession.connections.first {
            connection.isVideoMirrored = (device.position == .front)
            connection.videoOrientation = .portrait
        }

        captureSession.commitConfiguration()
        if !captureSession.isRunning{
            startSession()
        }
    }
    
    func switchCamera() {
        self.captureSession.beginConfiguration()

        // Remove all inputs
        for input in self.captureSession.inputs {
            self.captureSession.removeInput(input)
        }

        // Toggle camera position
        self.currentCameraPosition = self.currentCameraPosition.toggle

        // Select new camera
        guard let newCamera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: self.currentCameraPosition) else {
            print("Failed to get new camera.")
            self.captureSession.commitConfiguration()
            return
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
            }
        } catch {
            print("Failed to switch camera: \(error)")
            self.captureSession.commitConfiguration()
            return
        }

        // Mirror front camera
        if let connection = self.captureSession.connections.first {
            connection.isVideoMirrored = (self.currentCameraPosition == .front)
            connection.videoOrientation = .portrait
        }
        
        UIView.transition(with: self.cameraHolderView, duration: 0.5, options: .transitionFlipFromLeft, animations: {
            self.captureSession.commitConfiguration()
        })
    }
    
    func startSession() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .default).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .default).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
    }
    
    func didSelectFilter(newFilter: CameraFilter) {
        selectedFilterModel = newFilter
        intensitySlider.value = newFilter.defaultValue
        intensitySlider.minimumValue = newFilter.minValue
        intensitySlider.maximumValue = newFilter.maxValue
    }
    
    func didSelectFilter(newFilter: CIFilter) {
        selectedFilter = newFilter
        intensitySlider.value = 0
        intensitySlider.minimumValue = -1
        intensitySlider.maximumValue = 1
        
        if hasMediaPickedFromGallery{
            if mediaType == .photo{
                guard let selecteImage = originalSelectedImage else{return}
                currentCIImage = CIImageFilterManager.shared.applyFilters(to: selecteImage, filter: newFilter, val: 0)
            }
            else{
                
            }
        }
        
        if newFilter.name ==  "CIVignette"{
            setupOverlayPlayer()
        }
        else{
            stopOverlayPlayer()
        }
    }
    
    @objc func flipCameraTapped() {
        switchCamera()
    }
    
    @objc func capturePhoto(){
        guard let ciImage = currentCIImage else { return }

        let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
        guard let image = cgImage else { return }

        let uiImage = UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .up)

        // Save to photo library
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)

        // Optional: confirmation alert
        let alert = UIAlertController(title: "Saved", message: "Photo saved to library.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    @objc func recordVideo() {
        if isRecording {
            videoCaptureButton.tintColor = .systemBlue
            isRecording = false
            videoInput?.markAsFinished()
            assetWriter?.finishWriting {
                DispatchQueue.main.async {
                    if let outputURL = self.assetWriter?.outputURL {
                        UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, nil, nil, nil)
                        let alert = UIAlertController(title: "Saved", message: "Video saved to Photos.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        } else {
            videoCaptureButton.tintColor = .systemRed
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("output_\(UUID().uuidString).mp4")
            do {
                assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
                let settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: 720,
                    AVVideoHeightKey: 1280
                ]
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                videoInput?.expectsMediaDataInRealTime = true

                let bufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: 720,
                    kCVPixelBufferHeightKey as String: 1280
                ]
                if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
                    assetWriter?.add(videoInput)
                    pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                        assetWriterInput: videoInput,
                        sourcePixelBufferAttributes: bufferAttributes)
                }

                assetWriter?.startWriting()
                hasStartedSession = false
                isRecording = true
            } catch {
                print("AVAssetWriter setup failed: \(error)")
            }
        }
    }
}

// MARK: -  AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Grab the pixelbuffer frame from the camera output
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        var ciimage = CIImage(cvPixelBuffer: pixelBuffer)
        var filtered: CIImage? = nil
        
        let sliderValue = DispatchQueue.main.sync {
            return intensitySlider.value
        }
        if let selectedFilterModel {
            filtered = CameraFilterManager.shared.apply(filter: selectedFilterModel, to: ciimage, with: sliderValue)
            if let filteredImage = filtered {
                ciimage = filteredImage
            }
        }
        else if let selectedFilter{
            filtered = CIImageFilterManager.shared.applyFilters(to: ciimage, filter: selectedFilter, val: sliderValue)
            if let filteredImage = filtered {
                ciimage = filteredImage
            }
        }

        
        // Attempt to get overlay frame
        if let output = overlayVideoOutput,
           let overlayPixelBuffer = output.copyPixelBuffer(forItemTime: overlayPlayer!.currentTime(), itemTimeForDisplay: nil) {
            
            let overlayCI = CIImage(cvPixelBuffer: overlayPixelBuffer).resizeCIImage(to: ciimage.extent.size)

            // Composite overlay on top of camera
            let composite = CIFilter.sourceOverCompositing()
            composite.inputImage = overlayCI?.setOpacity(alpha: 0.7)
            composite.backgroundImage = ciimage
            if let compositedImage = composite.outputImage {
                ciimage = compositedImage
            }
        }
        
        DispatchQueue.main.async {
            self.currentCIImage = ciimage
        }

        // Video recording: append pixel buffer if recording
        if isRecording,
           let pixelBufferPool = pixelBufferAdaptor?.pixelBufferPool,
           let pixelBuffer = createPixelBuffer(from: ciimage, using: pixelBufferPool) {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if !hasStartedSession {
                assetWriter?.startSession(atSourceTime: timestamp)
                recordingStartTime = timestamp
                hasStartedSession = true
            }
            if videoInput?.isReadyForMoreMediaData == true {
                pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: timestamp)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let attachment = sampleBuffer.attachments[.droppedFrameReason],
              let resone = attachment.value as? String else{return}
    
        switch resone as CFString{
        case kCMSampleBufferDroppedFrameReason_FrameWasLate:
            print("🔴 frame was late")
        case kCMSampleBufferDroppedFrameReason_OutOfBuffers:
            print("🔴 too many buffers")
        case kCMSampleBufferDroppedFrameReason_Discontinuity:
            print("🔴 system failure")
        default:
            print("🔴 unknown reason")
        }
    }
}

// Helper method for pixel buffer creation from CIImage
extension CameraViewController {
    func createPixelBuffer(from image: CIImage, using pool: CVPixelBufferPool) -> CVPixelBuffer? {
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else { return nil }

        let pixelBufferSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let scaleX = pixelBufferSize.width / image.extent.width
        let scaleY = pixelBufferSize.height / image.extent.height
        let scale = min(scaleX, scaleY)

        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let xOffset = (pixelBufferSize.width - scaledImage.extent.width) / 2
        let yOffset = (pixelBufferSize.height - scaledImage.extent.height) / 2
        let centeredImage = scaledImage.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))

        ciContext.render(centeredImage, to: pixelBuffer)
        return pixelBuffer
    }
}

// MARK: - MTKViewDelegate
extension CameraViewController: MTKViewDelegate {
    func draw(in view: MTKView) {
        guard
            let commandBuffer = metalCommandQueue.makeCommandBuffer(),
            let ciImage = currentCIImage,
            let currentDrawable = view.currentDrawable else {
            return
        }
        
        let drawSize = cameraView.drawableSize
        let scaleX = drawSize.width / ciImage.extent.width
        let scaleY = drawSize.height / ciImage.extent.height
        let scale = min(scaleX, scaleY)

        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let xOffset = (drawSize.width - scaledImage.extent.width) / 2
        let yOffset = (drawSize.height - scaledImage.extent.height) / 2
        let translatedImage = scaledImage.transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
        
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = currentDrawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.endEncoding()
        }

        self.ciContext.render(
            translatedImage,
            to: currentDrawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(origin: .zero, size: drawSize),
            colorSpace: CGColorSpaceCreateDeviceRGB())
        
        
        commandBuffer.addCompletedHandler { buffer in
            self.delegate?.capture(texture: self.cameraView.currentDrawable?.texture)
        }
        
        // register drawable to command buffer
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op
    }
}

//MARK: - photo picker
extension CameraViewController{

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        hasMediaPickedFromGallery = true
        mediaType = .photo
        guard let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let uiImage = image as? UIImage, let cgImage = uiImage.cgImage else { return }
            let ciImage = CIImage(cgImage: cgImage)
            self.originalSelectedImage = ciImage
            DispatchQueue.main.async {[unowned self] in
                if let filter = self.selectedFilterModel{
                    self.currentCIImage = CameraFilterManager.shared.apply(filter: filter, to: ciImage, with: self.intensitySlider.value)
                }
                else if let filter = self.selectedFilter{
                    self.currentCIImage = CIImageFilterManager.shared.applyFilters(to: ciImage, filter: filter, val: self.intensitySlider.value)
                }
                else{
                    self.currentCIImage = ciImage
                }
            }
        }
    }
}

//MARK: - Overlay video
extension CameraViewController{
    func setupOverlayPlayer() {
        guard let overlayURL = Bundle.main.url(forResource: "overlayVideo", withExtension: "mp4") else { return }
        let asset = AVAsset(url: overlayURL)
        let item = AVPlayerItem(asset: asset)
        
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ])
        
        item.add(output)
        overlayPlayer = AVPlayer(playerItem: item)
        overlayVideoOutput = output
        
        overlayPlayer?.play()
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.overlayPlayer?.seek(to: .zero)
            self?.overlayPlayer?.play()
        }
    }
    
    func stopOverlayPlayer() {
        guard let _ = overlayPlayer else{return}
        // Stop playback
        overlayPlayer?.pause()
        
        // Remove player item and output
        overlayPlayer?.replaceCurrentItem(with: nil)
        overlayVideoOutput = nil
        
        // Remove notifications
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Deallocate player
        overlayPlayer = nil
    }
}
