//
//  ViewController.swift
//  visionMockup
//
//  Created by Kevin Chen on 3/3/2019.
//  Copyright © 2019 New York University. All rights reserved.
//

import UIKit
import Firebase

@objc(ViewController)
class ViewController: UIViewController, UINavigationControllerDelegate {
    
    lazy var vision = Vision.vision()
    // [END init_vision]
    
    /// A string holding current results from detection.
    var resultsText = ""
    
    /// An overlay view that displays detection annotations.
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    /// An image picker for accessing the photo library or camera.
    var imagePicker = UIImagePickerController()
    
    // Image counter.
    var currentImage = 0
    
    @IBOutlet weak var detectButton: UIBarButtonItem!
    @IBOutlet weak var detectorPicker: UIPickerView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var photoCameraButton: UIBarButtonItem!
    @IBOutlet weak var videoCameraButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        imageView.image = UIImage(named: Constants.images[currentImage])
        imageView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            ])
        
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        
        detectorPicker.delegate = self
        detectorPicker.dataSource = self
        
        let isCameraAvailable = UIImagePickerController.isCameraDeviceAvailable(.front) ||
            UIImagePickerController.isCameraDeviceAvailable(.rear)
        if isCameraAvailable {
            // `CameraViewController` uses `AVCaptureDevice.DiscoverySession` which is only supported for
            // iOS 10 or newer.
            if #available(iOS 10.0, *) {
                videoCameraButton.isEnabled = true
            }
        } else {
            photoCameraButton.isEnabled = false
        }
        
        let defaultRow = (DetectorPickerRow.rowsCount / 2) - 1
        detectorPicker.selectRow(defaultRow, inComponent: 0, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.navigationBar.isHidden = false
        
    }
    
    @IBAction func detect(_ sender: Any) {
        clearResults()
        let row = detectorPicker.selectedRow(inComponent: 0)
        if let rowIndex = DetectorPickerRow(rawValue: row) {
            detectLabels(image: imageView.image)
        }
        else {
            print("No such item at row \(row) in detector picker.")
        }
    }
    
    @IBAction func openPhotoLibrary(_ sender: Any) {
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true)
    }
    
    @IBAction func openCamera(_ sender: Any) {
        guard UIImagePickerController.isCameraDeviceAvailable(.front) ||
            UIImagePickerController.isCameraDeviceAvailable(.rear)
            else {
                return
        }
        imagePicker.sourceType = .camera
        present(imagePicker, animated: true)
    }
    
    @IBAction func changeImage(_ sender: Any) {
        clearResults()
        currentImage = (currentImage + 1) % Constants.images.count
        imageView.image = UIImage(named: Constants.images[currentImage])
    }
    
    /// Removes the detection annotations from the annotation overlay view.
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    /// Clears the results text view and removes any frames that are visible.
    private func clearResults() {
        removeDetectionAnnotations()
        self.resultsText = ""
    }
    
    private func showResults() {
        let resultsAlertController = UIAlertController(
            title: "Detection Results",
            message: nil,
            preferredStyle: .actionSheet
        )
        resultsAlertController.addAction(
            UIAlertAction(title: "OK", style: .destructive) { _ in
                resultsAlertController.dismiss(animated: true, completion: nil)
            }
        )
        resultsAlertController.message = resultsText
        resultsAlertController.popoverPresentationController?.barButtonItem = detectButton
        resultsAlertController.popoverPresentationController?.sourceView = self.view
        present(resultsAlertController, animated: true, completion: nil)
        print(resultsText)
    }
    
    /// Updates the image view with a scaled version of the given image.
    private func updateImageView(with image: UIImage) {
        let orientation = UIApplication.shared.statusBarOrientation
        var scaledImageWidth: CGFloat = 0.0
        var scaledImageHeight: CGFloat = 0.0
        switch orientation {
        case .portrait, .portraitUpsideDown, .unknown:
            scaledImageWidth = imageView.bounds.size.width
            scaledImageHeight = image.size.height * scaledImageWidth / image.size.width
        case .landscapeLeft, .landscapeRight:
            scaledImageWidth = image.size.width * scaledImageHeight / image.size.height
            scaledImageHeight = imageView.bounds.size.height
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // Scale image while maintaining aspect ratio so it displays better in the UIImageView.
            var scaledImage = image.scaledImage(
                with: CGSize(width: scaledImageWidth, height: scaledImageHeight)
            )
            scaledImage = scaledImage ?? image
            guard let finalImage = scaledImage else { return }
            DispatchQueue.main.async {
                self.imageView.image = finalImage
            }
        }
    }
    
    private func transformMatrix() -> CGAffineTransform {
        guard let image = imageView.image else { return CGAffineTransform() }
        let imageViewWidth = imageView.frame.size.width
        let imageViewHeight = imageView.frame.size.height
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        let imageViewAspectRatio = imageViewWidth / imageViewHeight
        let imageAspectRatio = imageWidth / imageHeight
        let scale = (imageViewAspectRatio > imageAspectRatio) ?
            imageViewHeight / imageHeight :
            imageViewWidth / imageWidth
        
        // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
        // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
        let scaledImageWidth = imageWidth * scale
        let scaledImageHeight = imageHeight * scale
        let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
        let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)
        
        var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
    }
    
    private func pointFrom(_ visionPoint: VisionPoint) -> CGPoint {
        return CGPoint(x: CGFloat(visionPoint.x.floatValue), y: CGFloat(visionPoint.y.floatValue))
    }
    
    private func addContours(forFace face: VisionFace, transform: CGAffineTransform) {
        // Face
        if let faceContour = face.contour(ofType: .face) {
            for point in faceContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        
        // Eyebrows
        if let topLeftEyebrowContour = face.contour(ofType: .leftEyebrowTop) {
            for point in topLeftEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom) {
            for point in bottomLeftEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let topRightEyebrowContour = face.contour(ofType: .rightEyebrowTop) {
            for point in topRightEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom) {
            for point in bottomRightEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        
        // Eyes
        if let leftEyeContour = face.contour(ofType: .leftEye) {
            for point in leftEyeContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius                )
            }
        }
        if let rightEyeContour = face.contour(ofType: .rightEye) {
            for point in rightEyeContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        
        // Lips
        if let topUpperLipContour = face.contour(ofType: .upperLipTop) {
            for point in topUpperLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let bottomUpperLipContour = face.contour(ofType: .upperLipBottom) {
            for point in bottomUpperLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let topLowerLipContour = face.contour(ofType: .lowerLipTop) {
            for point in topLowerLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let bottomLowerLipContour = face.contour(ofType: .lowerLipBottom) {
            for point in bottomLowerLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        
        // Nose
        if let noseBridgeContour = face.contour(ofType: .noseBridge) {
            for point in noseBridgeContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let noseBottomContour = face.contour(ofType: .noseBottom) {
            for point in noseBottomContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
    }
    
    private func addLandmarks(forFace face: VisionFace, transform: CGAffineTransform) {
        // Mouth
        if let bottomMouthLandmark = face.landmark(ofType: .mouthBottom) {
            let point = pointFrom(bottomMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.largeDotRadius
            )
        }
        if let leftMouthLandmark = face.landmark(ofType: .mouthLeft) {
            let point = pointFrom(leftMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.largeDotRadius
            )
        }
        if let rightMouthLandmark = face.landmark(ofType: .mouthRight) {
            let point = pointFrom(rightMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.largeDotRadius
            )
        }
        
        // Nose
        if let noseBaseLandmark = face.landmark(ofType: .noseBase) {
            let point = pointFrom(noseBaseLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.yellow,
                radius: Constants.largeDotRadius
            )
        }
        
        // Eyes
        if let leftEyeLandmark = face.landmark(ofType: .leftEye) {
            let point = pointFrom(leftEyeLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.cyan,
                radius: Constants.largeDotRadius
            )
        }
        if let rightEyeLandmark = face.landmark(ofType: .rightEye) {
            let point = pointFrom(rightEyeLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.cyan,
                radius: Constants.largeDotRadius
            )
        }
        
        // Ears
        if let leftEarLandmark = face.landmark(ofType: .leftEar) {
            let point = pointFrom(leftEarLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.purple,
                radius: Constants.largeDotRadius
            )
        }
        if let rightEarLandmark = face.landmark(ofType: .rightEar) {
            let point = pointFrom(rightEarLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.purple,
                radius: Constants.largeDotRadius
            )
        }
        
        // Cheeks
        if let leftCheekLandmark = face.landmark(ofType: .leftCheek) {
            let point = pointFrom(leftCheekLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.orange,
                radius: Constants.largeDotRadius
            )
        }
        if let rightCheekLandmark = face.landmark(ofType: .rightCheek) {
            let point = pointFrom(rightCheekLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.orange,
                radius: Constants.largeDotRadius
            )
        }
    }
    
    private func process(_ visionImage: VisionImage, with textRecognizer: VisionTextRecognizer?) {
        textRecognizer?.process(visionImage) { text, error in
            guard error == nil, let text = text else {
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "Text recognizer failed with error: \(errorString)"
                self.showResults()
                return
            }
            // Blocks.
            for block in text.blocks {
                let transformedRect = block.frame.applying(self.transformMatrix())
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.purple
                )
                
                // Lines.
                for line in block.lines {
                    let transformedRect = line.frame.applying(self.transformMatrix())
                    UIUtilities.addRectangle(
                        transformedRect,
                        to: self.annotationOverlayView,
                        color: UIColor.orange
                    )
                    
                    // Elements.
                    for element in line.elements {
                        let transformedRect = element.frame.applying(self.transformMatrix())
                        UIUtilities.addRectangle(
                            transformedRect,
                            to: self.annotationOverlayView,
                            color: UIColor.green
                        )
                        let label = UILabel(frame: transformedRect)
                        label.text = element.text
                        label.adjustsFontSizeToFitWidth = true
                        self.annotationOverlayView.addSubview(label)
                    }
                }
            }
            self.resultsText += "\(text.text)\n"
            self.showResults()
        }
    }
    
    private func process(
        _ visionImage: VisionImage,
        with documentTextRecognizer: VisionDocumentTextRecognizer?
        ) {
        documentTextRecognizer?.process(visionImage) { text, error in
            guard error == nil, let text = text else {
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "Document text recognizer failed with error: \(errorString)"
                self.showResults()
                return
            }
            // Blocks.
            for block in text.blocks {
                let transformedRect = block.frame.applying(self.transformMatrix())
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.purple
                )
                
                // Paragraphs.
                for paragraph in block.paragraphs {
                    let transformedRect = paragraph.frame.applying(self.transformMatrix())
                    UIUtilities.addRectangle(
                        transformedRect,
                        to: self.annotationOverlayView,
                        color: UIColor.orange
                    )
                    
                    // Words.
                    for word in paragraph.words {
                        let transformedRect = word.frame.applying(self.transformMatrix())
                        UIUtilities.addRectangle(
                            transformedRect,
                            to: self.annotationOverlayView,
                            color: UIColor.green
                        )
                        
                        // Symbols.
                        for symbol in word.symbols {
                            let transformedRect = symbol.frame.applying(self.transformMatrix())
                            UIUtilities.addRectangle(
                                transformedRect,
                                to: self.annotationOverlayView,
                                color: UIColor.cyan
                            )
                            let label = UILabel(frame: transformedRect)
                            label.text = symbol.text
                            label.adjustsFontSizeToFitWidth = true
                            self.annotationOverlayView.addSubview(label)
                        }
                    }
                }
            }
            self.resultsText += "\(text.text)\n"
            self.showResults()
        }
    }
}

extension ViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    
    // MARK: - UIPickerViewDataSource
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return DetectorPickerRow.componentsCount
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return DetectorPickerRow.rowsCount
    }
    
    // MARK: - UIPickerViewDelegate
    func pickerView(
        _ pickerView: UIPickerView,
        titleForRow row: Int,
        forComponent component: Int
        ) -> String? {
        return DetectorPickerRow(rawValue: row)?.description
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        clearResults()
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey : Any]
        ) {
        clearResults()
        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            updateImageView(with: pickedImage)
        }
        dismiss(animated: true)
    }
}

/// Extension of ViewController for On-Device and Cloud detection.
extension ViewController {
    
    /// Detects labels on the specified image using On-Device label API.
    ///
    /// - Parameter image: The image.
    func detectLabels(image: UIImage?) {
        guard let image = image else { return }
        
        // [START config_label]
        let options = VisionOnDeviceImageLabelerOptions()
        options.confidenceThreshold = Constants.labelConfidenceThreshold
        // [END config_label]
        
        // [START init_label]
        let onDeviceLabeler = vision.onDeviceImageLabeler(options: options)
        // [END init_label]
        
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        // [START detect_label]
        onDeviceLabeler.process(visionImage) { labels, error in
            guard error == nil, let labels = labels, !labels.isEmpty else {
                // [START_EXCLUDE]
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "On-Device label detection failed with error: \(errorString)"
                self.showResults()
                // [END_EXCLUDE]
                return
            }
            
            // [START_EXCLUDE]
            self.resultsText = labels.map { label -> String in
                return "Label: \(label.text), " +
                    "Confidence: \(label.confidence ?? 0), " +
                "EntityID: \(label.entityID ?? "")"
                }.joined(separator: "\n")
            self.showResults()
            // [END_EXCLUDE]
        }
        // [END detect_label]
    }
}

// MARK: - Enums

private enum DetectorPickerRow: Int {
    case detectFaceOnDevice = 0,
    detectImageLabelsOnDevice

    
    static let rowsCount = 1
    static let componentsCount = 1
    
    public var description: String {
        return "Image Labeling On-Device"
    }
}

private enum Constants {
    static let images = ["grace_hopper.jpg", "barcode_128.png", "qr_code.jpg", "beach.jpg",
                         "image_has_text.jpg", "liberty.jpg"]
    static let modelExtension = "tflite"
    static let localModelName = "mobilenet"
    static let quantizedModelFilename = "mobilenet_quant_v1_224"
    
    static let detectionNoResultsMessage = "No results returned."
    static let failedToDetectObjectsMessage = "Failed to detect objects in image."
    
    static let labelConfidenceThreshold: Float = 0.75
    static let smallDotRadius: CGFloat = 5.0
    static let largeDotRadius: CGFloat = 10.0
    static let lineColor = UIColor.yellow.cgColor
    static let fillColor = UIColor.clear.cgColor
}
