//
//  ViewController.swift
//  TextDetection
//
//  Created by Bernardo Sarto de Lucena on 4/21/18.
//  Copyright © 2018 Bernardo Sarto de Lucena. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    // create the live stream to detect text. This initalizes an object of AVCaptureSession that performs a real-time or offline capture. It is used whenever you want to perform some actions based on a live stream. Next, we need to connect the session to our device.
    var session = AVCaptureSession()
    
    // Creating a request
    var requests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        startLiveVideo()
        startTextDetection()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLayoutSubviews() {
        imageView.layer.sublayers?[0].frame = imageView.bounds
    }
    
    func startLiveVideo() {
        // We begin by modifying the settings of our AVCaptureSession. Then, we set the AVMediaType as video because we want a live stream so it should always be continuously running.
        session.sessionPreset = AVCaptureSession.Preset.photo
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        // Next, we define the device input and output. The input is what the camera is seeing and the output is what the video should appear as. We want the video to appear as a kCVPixelFormatType_32BGRA which is a type of video format. You can learn more about pixel format types here. Lastly, we add the input and output to the AVCaptureSession.
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
        let deviceOutput = AVCaptureVideoDataOutput()
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)
        
        // Finally, we add a sublayer containing the video preview to the imageView and get the session running.
        let imageLayer = AVCaptureVideoPreviewLayer(session: session)
        imageLayer.frame = imageView.bounds
        imageView.layer.addSublayer(imageLayer)
        
        session.startRunning()
    }
    
    // In this function, we create a constant textRequest that is a VNDetectTextRectanglesRequest. Basically it is just a specific type of VNRequest that only looks for rectangles with some text in them. When the framework has completed this request, we want it to call the function detectTextHandler. We also want to know exactly what the framework has recognized which is why we set the property reportCharacterBoxes equal to true. Finally, we set the variable requests created earlier to textRequest.
    func startTextDetection() {
        let textRequest = VNDetectTextRectanglesRequest(completionHandler: self.detectTextHandler)
        textRequest.reportCharacterBoxes = true
        self.requests = [textRequest]
    }
    
    // In this code, we begin by defining a constant observations which will contain all the results of our VNDetectTextRectanglesRequest. Next, we define another constant named result which will go through all the results of the request and transform them into the type of VNTextObservation.
    func detectTextHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results else {
            print("no result")
            return
        }
        
        let result = observations.map({$0 as? VNTextObservation})
        
        // We begin by having the code run asynchronously. First, we remove the bottommost layer in our imageView (if you noticed, we were adding a lot of layers to our imageView). Next, we check to see if a region exists within the results from our VNTextObservation. Now, we call in our function which draws a box around the region, or as we defined it, the word. Then, we check to see if there are character boxes within the region. If there are, we call in the function which draws a box around each letter.
        DispatchQueue.main.async() {
            self.imageView.layer.sublayers?.removeSubrange(1...)
            for region in result {
                guard let rg = region else {
                    continue
                }
                
                self.highlightWord(box: rg)
                
                if let boxes = region?.characterBoxes {
                    for characterBox in boxes {
                        self.highlightLetters(box: characterBox)
                    }
                }
            }
        }
    }
    
    // In this function we begin by defining a constant named boxes which is a combination of all the characterBoxes our request has found. Then, we define some points on our view to help us position our boxes. Finally, we create a CALayer with the given constraints defined and apply it to our imageView.
    func highlightWord(box: VNTextObservation) {
        guard let boxes = box.characterBoxes else {
            return
        }
        
        var maxX: CGFloat = 9999.0
        var minX: CGFloat = 0.0
        var maxY: CGFloat = 9999.0
        var minY: CGFloat = 0.0
        
        for char in boxes {
            if char.bottomLeft.x < maxX {
                maxX = char.bottomLeft.x
            }
            if char.bottomRight.x > minX {
                minX = char.bottomRight.x
            }
            if char.bottomRight.y < maxY {
                maxY = char.bottomRight.y
            }
            if char.topRight.y > minY {
                minY = char.topRight.y
            }
        }
        
        let xCord = maxX * imageView.frame.size.width
        let yCord = (1 - minY) * imageView.frame.size.height
        let width = (minX - maxX) * imageView.frame.size.width
        let height = (minY - maxY) * imageView.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 2.0
        outline.borderColor = UIColor.red.cgColor
        
        imageView.layer.addSublayer(outline)
    }
    
    // we use the VNRectangleObservation to define our constraints that will make outlining the box easier.
    func highlightLetters(box: VNRectangleObservation) {
        let xCord = box.topLeft.x * imageView.frame.size.width
        let yCord = (1 - box.topLeft.y) * imageView.frame.size.height
        let width = (box.topRight.x - box.bottomLeft.x) * imageView.frame.size.width
        let height = (box.topLeft.y - box.bottomLeft.y) * imageView.frame.size.height
        
        let outline = CALayer()
        outline.frame = CGRect(x: xCord, y: yCord, width: width, height: height)
        outline.borderWidth = 1.0
        outline.borderColor = UIColor.blue.cgColor
        
        imageView.layer.addSublayer(outline)
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // Hang in there! It’s our last part of the code. The extension adopts the AVCaptureVideoDataOutputSampleBufferDelegate protocol. Basically what this function does is that it checks if the CMSampleBuffer exists and is giving an AVCaptureOutput. Next, we create a variable requestOptions which is a dictionary for the type VNImageOption. VNImageOption is a type of structure that can hold the properties and data from the camera. Finally we create a VNImageRequestHandler object and perform the text request that we create earlier.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        var requestOptions:[VNImageOption : Any] = [:]
        
        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics:camData]
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
        
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
}
