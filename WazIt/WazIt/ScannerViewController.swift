//
//  ScannerViewController.swift
//  SceneDetector
//
//  Created by LongTa on 11/4/17.
//  Copyright © 2017 Ray Wenderlich. All rights reserved.
//

import UIKit
import AVFoundation
import Foundation
import CoreML
import Vision

class ScannerViewController: UIViewController {
  
    
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var imageViewCaptured: UIImageView!
    @IBOutlet weak var buttonSnap: UIButton!
    @IBOutlet weak var predictionLabel: UILabel!
    let captureSession = AVCaptureSession()
    let stillImageOutput = AVCaptureStillImageOutput()
    var previewLayer : AVCaptureVideoPreviewLayer?
    let vowels: [Character] = ["a", "e", "i", "o", "u"]
    let speechSynthesizer = AVSpeechSynthesizer()
    // If we find a device we'll store it here for later use
    var captureDevice : AVCaptureDevice?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        initialCamera()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: - IBActions
extension ScannerViewController {
    
    @IBAction func pickImage(_ sender: Any) {
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.sourceType = .savedPhotosAlbum
        present(pickerController, animated: true)
    }
    
    @IBAction func close(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func snap(_ sender: Any) {
        if self.imageViewCaptured.image == nil{
            capture()
        }
        else{
            self.imageViewCaptured.image = nil
        }
    }
    
    @IBAction func speak(_ sender: Any){
        if let predictionText = self.predictionLabel.text{
            let speechUtterance = AVSpeechUtterance(string: predictionText)
            speechSynthesizer.speak(speechUtterance)
        }
        
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ScannerViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        dismiss(animated: true)
        
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            fatalError("couldn't load image from Photos")
        }
        
        imageViewCaptured.image = image
        classifyScene(image: image)
    }
}

// MARK: - UINavigationControllerDelegate
extension ScannerViewController: UINavigationControllerDelegate {
}

// MARK: - Methods
extension ScannerViewController {
    func initialCamera() {
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        if let devices = AVCaptureDevice.devices() as? [AVCaptureDevice] {
            // Loop through all the capture devices on this phone
            for device in devices {
                // Make sure this particular device supports video
                if (device.hasMediaType(AVMediaType.video)) {
                    // Finally check the position and confirm we've got the back camera
                    if(device.position == AVCaptureDevice.Position.back) {
                        captureDevice = device
                        if captureDevice != nil {
                            print("Capture device found")
                            beginSession()
                        }
                    }
                }
            }
        }
    }
    
    func beginSession() {
        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice!))
            stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecType.jpeg]
            
            if captureSession.canAddOutput(stillImageOutput) {
                captureSession.addOutput(stillImageOutput)
            }
            
        }
        catch {
            print("error: \(error.localizedDescription)")
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.view.layer.addSublayer(previewLayer)
        previewLayer.frame = self.view.layer.frame
        captureSession.startRunning()
        self.view.addSubview(overlayView)
    }
    
    func capture() {
        if let videoConnection = stillImageOutput.connection(with: AVMediaType.video) {
            stillImageOutput.captureStillImageAsynchronously(from: videoConnection, completionHandler: { (CMSampleBuffer, Error) in
                
                if let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(CMSampleBuffer!) {
                    if let cameraImage = UIImage(data: imageData) {
                        //UIImageWriteToSavedPhotosAlbum(cameraImage, nil, nil, nil)
                        self.imageViewCaptured.image = cameraImage;
                        self.buttonSnap.setTitle("Retake", for: UIControlState.normal)
                        self.classifyScene(image: cameraImage)
                    }
                }
            })
        }
    }
    
    func classifyScene(image: UIImage) {
        
        guard let ciImage = CIImage(image: image) else {
            fatalError("couldn't convert UIImage to CIImage")
        }
        
        predictionLabel.text = "detecting scene..."
        
        // Load the ML model through its generated class
        //guard let model = try? VNCoreMLModel(for: GoogLeNetPlaces().model) else {
        guard let model = try? VNCoreMLModel(for: MobileNet().model) else {
            fatalError("can't load Places ML model")
        }
     
        // Create a Vision request with completion handler
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation],
                let topResult = results.first else {
                    fatalError("unexpected result type from VNCoreMLRequest")
            }
            
            // Update UI on main queue
            let article = (self?.vowels.contains(topResult.identifier.first!))! ? "an" : "a"
            DispatchQueue.main.async { [weak self] in
                self?.predictionLabel.text = "\(Int(topResult.confidence * 100))% it's \(article) \(topResult.identifier)"
            }
        }
        
        // Run the Core ML GoogLeNetPlaces classifier on global dispatch queue
        let handler = VNImageRequestHandler(ciImage: ciImage)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
}
