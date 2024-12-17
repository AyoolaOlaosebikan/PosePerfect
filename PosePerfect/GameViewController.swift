//
//  ARController.swift
//  PosePerfect
//
//  Created by Ayoola Olaosebikan on 12/3/24.
//

import AVFoundation
import SceneKit
import UIKit
import Vision

class GameViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet var cameraBackgroundView: UIView!
    @IBOutlet var sceneView: SCNView!

    @IBAction func resetPose(_ sender: UIButton) {
        startTraining(for: currentPoseKey)
    }
    
    var captureSession: AVCaptureSession!

    var isPoseMatchedBool: Bool = false
    
    var trainingTimer: Timer?
    
    var isViewActive: Bool = false

    let targetPoses: [String: [String: Double]] = [
        "front_biceps": ["LeftArmAngle": -150, "RightArmAngle": 150],
        "arnold": ["LeftArmAngle": -20, "RightArmAngle": 150],
        "side_chest": ["LeftArmAngle": -60, "RightArmAngle": 100],
        "side_tricep": ["LeftArmAngle": 15],
    ]

    var currentPoseObservation: VNHumanBodyPoseObservation?

    let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    
    var previousPoseKey: String?
    var currentPoseKey: String = "front_biceps"

    @IBOutlet var infoLabel: UILabel!

    override func viewDidLoad() {
        showPoseSelectionMenu()
        
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

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    func showPoseSelectionMenu() {
        let alert = UIAlertController(title: "Select a Pose", message: "Choose a pose to practice", preferredStyle: .alert)
        
        for poseKey in targetPoses.keys {
            alert.addAction(UIAlertAction(title: poseKey, style: .default, handler: { _ in
                self.startTraining(for: poseKey)
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func setupScene() {
        let scene = SCNScene()
               sceneView.scene = scene
               sceneView.allowsCameraControl = false
               sceneView.backgroundColor = .clear

               // Add a camera
               let cameraNode = SCNNode()
               cameraNode.camera = SCNCamera()
               cameraNode.position = SCNVector3(0, 0, 5) // Start position
               cameraNode.eulerAngles = SCNVector3(-Float.pi / 8, 0, 0) // Tilt downward
               scene.rootNode.addChildNode(cameraNode)

       //        let platformWidth: CGFloat = 5.0 // Adjust to control the size of the platform
       //        let platformLength: CGFloat = 10.0 // Length of the platform
       //
       //        // Create the platform geometry
       //        let platformNode = SCNNode(geometry: SCNPlane(width: platformWidth, height: platformLength))
       //        platformNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "grassTexture.png") // Apply a grass texture
       //        platformNode.geometry?.firstMaterial?.isDoubleSided = true // Make sure it's visible from all angles
       //
       //        // Rotate the plane to make it horizontal
       //        platformNode.eulerAngles = SCNVector3(-Float.pi / 4, 0, -Float.pi / 8)
       //        // Position the platform slightly below the cutout
       //        platformNode.position = SCNVector3(0.5, -2, -2) // Adjust y to lower the platform and z for alignment
       //        scene.rootNode.addChildNode(platformNode)

               ////
       //        let outlineNode = SCNNode(geometry: SCNBox(width: platformWidth + 0.01,
       //                                                   height: platformHeight + 0.01,
       //                                                   length: 20.2,
       //                                                   chamferRadius: 0))
       //        outlineNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black // Outline color
       //        outlineNode.geometry?.firstMaterial?.fillMode = .lines // Render as wireframe
       //        outlineNode.position = platformNode.position // Match position
       //        outlineNode.eulerAngles = platformNode.eulerAngles
       //        scene.rootNode.addChildNode(outlineNode)

               // Add a placeholder for the pose cutout
               let poseCutoutNode = SCNNode(geometry: SCNPlane(width: 2, height: 3))
               poseCutoutNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "front_biceps.png")
               poseCutoutNode.position = SCNVector3(2, 0, -2)
               poseCutoutNode.name = "PoseCutout"
               scene.rootNode.addChildNode(poseCutoutNode)
        
        print("PoseCutoutNode added at position: \(poseCutoutNode.position)")
            print("Scene children count: \(scene.rootNode.childNodes.count)")
           }

    func updateTrainingMode() {
        guard let poseCutoutNode = sceneView.scene?.rootNode.childNode(withName: "PoseCutout", recursively: true),
              let currentPoseObservation = currentPoseObservation else {
            print("No pose detected. Keeping cutout stationary.")
            return
            
        }
            
        poseCutoutNode.position.z += 0.012
                poseCutoutNode.position.x -= 0.012
        let detectedFeatures = extractFeatures(from: currentPoseObservation)

        if let targetPose = targetPoses[currentPoseKey] {
            if isPoseMatched(detectedFeatures: detectedFeatures, targetPose: targetPose) {
                isPoseMatchedBool = true
                infoLabel.text = "Pose Matched! Great Job!"
                infoLabel.textColor = .green
            } else {
                infoLabel.text = "Pose Not Matched. Try Again!"
                isPoseMatchedBool = false
                infoLabel.textColor = .red
            }
        }
        if poseCutoutNode.position.z > 0.2 {
                    if isPoseMatchedBool {
                        if poseCutoutNode.position.z > 1 {
                            resetCutoutPosition(poseCutoutNode)
                        }
                    } else {
                        poseCutoutNode.position.z -= 0.9
                        poseCutoutNode.position.x += 0.9
                    }
                }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.scene?.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            print("Scene nodes removed.")

            // Stop camera and timer
            if captureSession?.isRunning == true {
                captureSession.stopRunning()
            }
            captureSession = nil
            trainingTimer?.invalidate()
            trainingTimer = nil
    }

    func resetCutoutPosition(_ node: SCNNode) {
            node.position = SCNVector3(2, 0, -2)
            //  print("New pose challenge! Position reset.")

           
        }
    var frameCounter = 0
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isViewActive else { return } // Skip processing if view is not active
            frameCounter += 1
            if frameCounter % 10 == 0 {
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                processImage(pixelBuffer)
            }
    }

    func startTraining(for poseKey: String) {
        currentPoseKey = poseKey // Set the pose to practice
        previousPoseKey = poseKey // Update previous pose
        
        setupCamera()
        setupScene()
        trainingTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            self.updateTrainingMode()
        }

        if let poseCutoutNode = sceneView.scene?.rootNode.childNode(withName: "PoseCutout", recursively: true) {
            poseCutoutNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "\(poseKey).png") // Update cutout image
            poseCutoutNode.position = SCNVector3(2, 0, -2) // Reset position
            print("Training started for pose: \(poseKey)")
        }
        
        infoLabel.text = "Practice Pose: \(poseKey.capitalized)" // Update the info label
    }

    func isPoseMatched(detectedFeatures: [String: Double], targetPose: [String: Double]) -> Bool {
        for (key, targetValue) in targetPose {
            if let detectedValue = detectedFeatures[key] {
                print("\(key) and \(detectedValue) and \(targetValue)")
                if abs(detectedValue - targetValue) > 30 { // Allow a margin of error
                    return false
                }
            }
        }
        return true
    }
}

extension GameViewController {
    func processImage(_ pixelBuffer: CVPixelBuffer) {
        // Create the Vision request handler    DispatchQueue.global(qos: .userInitiated).async {
        DispatchQueue.global(qos: .userInitiated).async {
            
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            
            // Create the Vision request
            // let request = VNDetectHumanBodyPoseRequest()
            
            do {
                // Perform the request
                try requestHandler.perform([self.bodyPoseRequest])
                if let results = self.bodyPoseRequest.results, let firstPose = results.first {
                    DispatchQueue.main.async {
                        self.currentPoseObservation = firstPose
                        self.analyzePose(from: firstPose)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.currentPoseObservation = nil
                        print("No pose detected.")
                    }
                }
            } catch {
                print("Error performing Vision request: \(error.localizedDescription)")
            }
        }
    }

    func analyzePose(from observation: VNHumanBodyPoseObservation) {
        do {
            let recognizedPoints = try observation.recognizedPoints(.all)

            // Example: Get key joint positions
            if let leftWrist = recognizedPoints[.leftWrist], leftWrist.confidence > 0.5,
               let rightWrist = recognizedPoints[.rightWrist], rightWrist.confidence > 0.5 {
                // print("Left Wrist: \(leftWrist), Right Wrist: \(rightWrist)")

                // Perform pose-matching logic here
            }
        } catch {
            print("Error analyzing pose: \(error.localizedDescription)")
        }
    }
}

extension GameViewController {
    func calculateAngle(between point1: VNRecognizedPoint, and point2: VNRecognizedPoint) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        // print(atan2(dy, dx) * 180 / .pi)
        return atan2(dy, dx) * 180 / .pi // Convert radians to degrees
    }

    func extractFeatures(from observation: VNHumanBodyPoseObservation) -> [String: Double] {
        var features: [String: Double] = [:]

        do {
            let points = try observation.recognizedPoints(.all)

            // Arm angles
            if let leftElbow = points[.leftElbow], leftElbow.confidence > 0.5,
               let leftWrist = points[.leftWrist], leftWrist.confidence > 0.5 {
                features["LeftArmAngle"] = calculateAngle(between: leftElbow, and: leftWrist)
            }
            if let rightElbow = points[.rightElbow], rightElbow.confidence > 0.5,
               let rightWrist = points[.rightWrist], rightWrist.confidence > 0.5 {
                features["RightArmAngle"] = calculateAngle(between: rightElbow, and: rightWrist)
            }

            // Shoulder angles
            if let leftShoulder = points[.leftShoulder], leftShoulder.confidence > 0.5,
               let leftElbow = points[.leftElbow], leftElbow.confidence > 0.5 {
                features["LeftShoulderAngle"] = calculateAngle(between: leftShoulder, and: leftElbow)
            }
            if let rightShoulder = points[.rightShoulder], rightShoulder.confidence > 0.5,
               let rightElbow = points[.rightElbow], rightElbow.confidence > 0.5 {
                features["RightShoulderAngle"] = calculateAngle(between: rightShoulder, and: rightElbow)
            }

            // Hip angles
            if let leftHip = points[.leftHip], leftHip.confidence > 0.5,
               let leftKnee = points[.leftKnee], leftKnee.confidence > 0.5 {
                features["LeftHipAngle"] = calculateAngle(between: leftHip, and: leftKnee)
            }
            if let rightHip = points[.rightHip], rightHip.confidence > 0.5,
               let rightKnee = points[.rightKnee], rightKnee.confidence > 0.5 {
                features["RightHipAngle"] = calculateAngle(between: rightHip, and: rightKnee)
            }

            // Knee angles
            if let leftKnee = points[.leftKnee], leftKnee.confidence > 0.5,
               let leftAnkle = points[.leftAnkle], leftAnkle.confidence > 0.5 {
                features["LeftKneeAngle"] = calculateAngle(between: leftKnee, and: leftAnkle)
            }
            if let rightKnee = points[.rightKnee], rightKnee.confidence > 0.5,
               let rightAnkle = points[.rightAnkle], rightAnkle.confidence > 0.5 {
                features["RightKneeAngle"] = calculateAngle(between: rightKnee, and: rightAnkle)
            }

            // Torso angles
            if let leftShoulder = points[.leftShoulder], leftShoulder.confidence > 0.5,
               let leftHip = points[.leftHip], leftHip.confidence > 0.5 {
                features["LeftTorsoAngle"] = calculateAngle(between: leftShoulder, and: leftHip)
            }
            if let rightShoulder = points[.rightShoulder], rightShoulder.confidence > 0.5,
               let rightHip = points[.rightHip], rightHip.confidence > 0.5 {
                features["RightTorsoAngle"] = calculateAngle(between: rightShoulder, and: rightHip)
            }

        } catch {
            print("Error extracting features: \(error.localizedDescription)")
        }

        return features
    }
}
