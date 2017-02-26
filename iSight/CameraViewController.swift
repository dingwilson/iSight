//
//  CameraViewController.swift
//  iSight
//
//  Created by Wilson Ding on 2/25/17.
//  Copyright © 2017 Wilson Ding. All rights reserved.
//

import UIKit
import AVFoundation
import Clarifai
import Spark_SDK

class CameraViewController: UIViewController {
    
    @IBOutlet weak var previewView: UIView!
    
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCaptureStillImageOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    let deviceID = "30003e000947343337373738"
    
    var app : ClarifaiApp?
    
    var photon : SparkDevice? = nil
    
    @IBOutlet weak var takePhotoButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let path = Bundle.main.path(forResource: "Keys", ofType: "plist") {
            let dictRoot = NSDictionary(contentsOfFile: path)
            if let dict = dictRoot {
                let appID = (dict["appID"] as! String)
                let appSecret = (dict["appSecret"] as! String)
                
                app = ClarifaiApp(appID: appID, appSecret: appSecret)
            }
        }
        
        setupPhoton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        captureSession = AVCaptureSession()
        captureSession!.sessionPreset = AVCaptureSessionPresetPhoto
        
        let backCamera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        var error: Error?
        
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: backCamera)
        } catch let error1 {
            error = error1
            input = nil
        }
        
        if error == nil && captureSession!.canAddInput(input) {
            captureSession!.addInput(input)
            
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput!.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            if captureSession!.canAddOutput(stillImageOutput) {
                captureSession!.addOutput(stillImageOutput)
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer!.frame = previewView.bounds
                previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
                previewLayer!.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                previewView.layer.addSublayer(previewLayer!)
                
                captureSession!.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession!.stopRunning()
    }
    
    func analyzeImage(image: UIImage) {
        app?.getModelByName("general-v1.3", completion: { (model, error) in
            let clarifaiImage = ClarifaiImage(image: image)
            model?.predict(on: [clarifaiImage!], completion: {(outputs, error) in
                if error == nil {
                    let output = outputs?[0]
                    
                    var tags : [String] = []
                    
                    for concepts: ClarifaiConcept in (output?.concepts)! {
                        tags.append(concepts.conceptName)
                    }
                    
                    tags = self.sanitize(tags: tags)
                    
                    print(tags)
                    
                    self.sendWordToPhoton(word: tags[0])
                    
                    print(tags[0])
                }
            })
        })
    }
    
    func setupPhoton() {
        SparkCloud.sharedInstance().getDevice(self.deviceID, completion: { (device:SparkDevice?, error:Error?) -> Void in
            if let d = device {
                self.photon = d
            }
        })
    }
    
    func sendWordToPhoton(word: String) {
        let task = photon!.callFunction("word", withArguments: [word]) { (resultCode : NSNumber?, error : Error?) -> Void in
            if (error == nil) {
                print("Success")
            }
        }
    }
    
    func sanitize(tags: [String]) -> [String] { // Remove generic terms here
        var tags = tags.filter{$0 != "no person"}
        tags = tags.filter{$0 != "people"}
        
        return tags
    }
    
    func takePhoto() {
        if let videoConnection = stillImageOutput!.connection(withMediaType: AVMediaTypeVideo) {
            self.captureSession?.sessionPreset = AVCaptureSessionPresetMedium
            videoConnection.videoOrientation = AVCaptureVideoOrientation.portrait
            stillImageOutput?.captureStillImageAsynchronously(from: videoConnection, completionHandler: {(sampleBuffer, error) in
                if (sampleBuffer != nil) {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    let dataProvider = CGDataProvider(data: imageData as! CFData)
                    let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
                    
                    let image = UIImage(cgImage: cgImageRef!, scale: 1.0, orientation: UIImageOrientation.right)
                    
                    self.analyzeImage(image: image)
                }
            })
            self.captureSession?.sessionPreset = AVCaptureSessionPresetPhoto
        }
    }
    
    @IBAction func takePhotoButtonPressed(_ sender: Any) {
        self.takePhoto()
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    //override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    
    // }
}
