//
//  ARController.swift
//  PosePerfect
//
//  Created by Ayoola Olaosebikan on 12/3/24.
//

import AVFoundation
import UIKit
import Vision
import SceneKit

class GameViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet var cameraBackgroundView: UIView!
    @IBOutlet var sceneView: SCNView!

    var captureSession: AVCaptureSession!
    
    override func viewDidLoad() {
        setupCamera()
        setupScene()
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium

        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            fatalError("Front camera not available")
        }

        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            fatalError("Error accessing front camera: \(error.localizedDescription)")
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = cameraBackgroundView.bounds
        cameraBackgroundView.layer.addSublayer(previewLayer)
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    func setupScene() {
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.allowsCameraControl = false

        // Add a camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 5) // Start position
        scene.rootNode.addChildNode(cameraNode)

        // Add a placeholder for the pose cutout
        let poseCutoutNode = SCNNode(geometry: SCNPlane(width: 2, height: 3))
        poseCutoutNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "poseCutout.png")
        poseCutoutNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(poseCutoutNode)
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            self.scrollScene()
        }
    }

    func scrollScene() {
        sceneView.scene?.rootNode.childNodes.forEach { node in
            node.position.z -= 0.1 // Move everything backward to simulate scrolling
        }
    }
    
}
