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

enum AspectRatio: String, CaseIterable{
    case portrait = "Potrait"
    case landscape = "Landscape"
    case square = "Square"
    
    var size: CGSize{
        switch self {
        case .portrait:
            return CGSize(width: 320, height: 570)
        case .landscape:
            return CGSize(width: 414, height: 233)
        case .square:
            return CGSize(width: 320, height: 320)
        }
    }
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
    var currentCameraPosition: AVCaptureDevice.Position = .back
    
    //ratio
    var cameraViewHeightConstraint: NSLayoutConstraint!
    var cameraViewWidthConstraint: NSLayoutConstraint!
    
    // overlay view
    var overlayPlayer: AVPlayer?
    var overlayVideoOutput: AVPlayerItemVideoOutput?
    
    //photo picker
    var hasMediaPickedFromGallery: Bool = false
    var mediaType: MediaType? = .none
    var selectedAspectRatio: AspectRatio = .square
    var originalSelectedImage: CIImage? = nil
    
    var galleryDisplayLink: CADisplayLink?
    
    public var metalDevice: MTLDevice!
    public var metalCommandQueue: MTLCommandQueue!
    public var ciContext: CIContext!
    
    weak var delegate: cameraDelegate?
    var selectedFilterModel: CameraFilter?
    var selectedFilter: CIFilter?
    
    let switchButton = UIButton(type: .system)
    let ratioButton = UIButton(type: .system)
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
            cameraView.center(in: cameraHolderView)
            
            cameraViewWidthConstraint = cameraView.widthAnchor.constraint(equalToConstant: selectedAspectRatio.size.width)
            cameraViewHeightConstraint = cameraView.heightAnchor.constraint(equalToConstant: selectedAspectRatio.size.width)
            
            cameraViewHeightConstraint.isActive = true
            cameraViewWidthConstraint.isActive = true
            
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
        
        view.addSubview(ratioButton)
        ratioButton.setImage(.init(systemName: "aspectratio.fill"), for: .normal)
        ratioButton.addTarget(self, action: #selector(showAspectRatioSelection), for: .touchUpInside)
        ratioButton.anchorView(bottom: cameraHolderView.bottomAnchor)
        ratioButton.centerAnchor(x: cameraHolderView)
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
        
        alert.addAction(UIAlertAction(title: "Choose from Photo Library", style: .default, handler: {[unowned self] _ in
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1
            config.filter = .any(of: [.images, .videos])
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            self.present(picker, animated: true)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc func showAspectRatioSelection() {
        let ratios = AspectRatio.allCases
        
        let alert = UIAlertController(title: "Aspect Ratio", message: nil, preferredStyle: .actionSheet)
        
        for ratio in ratios {
            alert.addAction(UIAlertAction(title: ratio.rawValue, style: .default, handler: {[unowned self] _ in
                changeCameraFrame(to: ratio)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    
    func changeCameraFrame(to newRatio: AspectRatio){
        selectedAspectRatio = newRatio
        
        cameraViewWidthConstraint.constant = newRatio.size.width
        cameraViewHeightConstraint.constant = newRatio.size.height
        UIView.animate(withDuration: 0.3) {[unowned self] in
            view.layoutIfNeeded()
        }
    }
    
    func setupSession() {
        captureSession.beginConfiguration()
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
        output.connections.first?.isVideoMirrored = false
        
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
    
    
    func switchToCamera(device: AVCaptureDevice) {
        stopGalleryVideoObserver()
        
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
        if newFilter == selectedFilter{
            selectedFilter = nil
            stopOverlayPlayer()
            return
        }
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
            if hasMediaPickedFromGallery{return}
            stopOverlayPlayer()
        }
    }
    
    @objc func capturePhoto(){
        guard let ciImage = currentCIImage else { return }
        
        // 1. Crop to square
        let inputExtent = ciImage.extent
        let viewSize = cameraView.drawableSize
        let x = (inputExtent.width - viewSize.width) / 2
        let y = (inputExtent.height - viewSize.height) / 2
        let squareCropRect = CGRect(x: x,
                                    y: y,
                                    width: viewSize.width,
                                    height: viewSize.height)
        let croppedImage = ciImage.cropped(to: squareCropRect)
        
        let cgImage = ciContext.createCGImage(croppedImage, from: croppedImage.extent)
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
                    AVVideoWidthKey: cameraView.drawableSize.width,
                    AVVideoHeightKey: cameraView.drawableSize.height
                ]
                videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                videoInput?.expectsMediaDataInRealTime = true
                
                let bufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: cameraView.drawableSize.width,
                    kCVPixelBufferHeightKey as String: cameraView.drawableSize.height
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
        let scale = max(scaleX, scaleY)
        
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
        let scale = max(scaleX, scaleY)
        
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
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

//MARK: - photo picker
extension CameraViewController{
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let itemProvider = results.first?.itemProvider else {
            return
        }
        
        stopSession()
        hasMediaPickedFromGallery = true
        
        if itemProvider.canLoadObject(ofClass: UIImage.self){
            mediaType = .photo
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
        else{
            mediaType = .video
            itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [unowned self] url, error in
                guard let localURL = url else{return}
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(localURL.lastPathComponent)
                try? FileManager.default.copyItem(at: localURL, to: tempURL)
                
                let asset = AVAsset(url: tempURL)
                let item = AVPlayerItem(asset: asset)
                let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ])
                item.add(output)
                
                DispatchQueue.main.async {
                    self.overlayPlayer = AVPlayer(playerItem: item)
                    self.overlayVideoOutput = output
                    self.overlayVideoOutput?.requestNotificationOfMediaDataChange(withAdvanceInterval: 0.03)
                    self.overlayPlayer?.play()
                    self.setupGalleryVideoObserver()
                    
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                        self?.overlayPlayer?.seek(to: .zero)
                        self?.overlayPlayer?.play()
                    }
                }
            }
        }
        
        
    }
    
    func setupGalleryVideoObserver(){
        galleryDisplayLink?.invalidate()
        galleryDisplayLink = CADisplayLink(target: self, selector: #selector(self.updateGalleryFrame))
        galleryDisplayLink?.add(to: .main, forMode: .default)
    }
    
    @objc func updateGalleryFrame() {
        guard let output = overlayVideoOutput,
              let player = overlayPlayer else {
            print("⚠️ No player or output.")
            return
        }
        
        let currentTime = player.currentTime()
        guard currentTime.seconds > 0.01 else{return}
        guard output.hasNewPixelBuffer(forItemTime: currentTime),
              let pixelBuffer = output.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) else {
            print("⚠️ No pixel buffer available at time: \(currentTime.seconds)")
            return
        }
        
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        if let filterModel = selectedFilterModel {
            ciImage = CameraFilterManager.shared.apply(filter: filterModel, to: ciImage, with: intensitySlider.value) ?? ciImage
        } else if let filter = selectedFilter {
            ciImage = CIImageFilterManager.shared.applyFilters(to: ciImage, filter: filter, val: intensitySlider.value) ?? ciImage
        }
        
        DispatchQueue.main.async {
            self.currentCIImage = ciImage
        }
    }
    
    func stopGalleryVideoObserver(){
        hasMediaPickedFromGallery = false
        mediaType = nil
        originalSelectedImage = nil
        currentCIImage = nil
        galleryDisplayLink?.invalidate()
        galleryDisplayLink = nil
        stopOverlayPlayer()
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
