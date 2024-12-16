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

class GameViewController: UIViewController {
    @IBOutlet var cameraBackgroundView: UIView!
    @IBOutlet var sceneView: SCNView!

    var captureSession: AVCaptureSession!
    
    var isPoseMatched: Bool = true
    
    let targetPoses: [String: [String: Double]] = [
        "front_biceps": ["LeftArmAngle": 120, "RightArmAngle": 120],
        "arnold": ["LeftArmAngle": 0, "RightArmAngle": 120],
        "side_chest": ["LeftArmAngle": 110, "RightArmAngle": 110],
        "side_tricep": ["LeftArmAngle": 90, "RightArmAngle": 50]
        
    ]
    
    var currentPoseObservation: VNHumanBodyPoseObservation?
    
    var previousPoseKey: String? = nil

    override func viewDidLoad() {
        setupCamera()
        setupScene()
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            self.updateGame()
        }
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
//        platformNode.position = SCNVector3(0.5, -2, -2) // Adjust `y` to lower the platform and `z` for alignment
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
        
        
    }
    
    func updateGame() {
            guard let poseCutoutNode = sceneView.scene?.rootNode.childNode(withName: "PoseCutout", recursively: true) else { return }
            poseCutoutNode.position.z += 0.012
            poseCutoutNode.position.x -= 0.012
            if let currentPoseObservation = currentPoseObservation {
                let detectedFeatures = extractFeatures(from: currentPoseObservation)
                if isPoseMatched(detectedFeatures: detectedFeatures, targetPose: targetPoses["Front Double Biceps"]!) {
                    // Move the cutout closer
                   
                    isPoseMatched = true
                    print("Pose matched! Moving cutout.")
                } else {
//                    poseCutoutNode.position.z -= 0.1
//                    poseCutoutNode.position.x -= 0.1
                    print("Pose not matched. Try again.")
                }
            }

            // Reset position or advance to next level
        if poseCutoutNode.position.z > 0.2 {
                if isPoseMatched {
                    if poseCutoutNode.position.z > 1 {
                        resetCutoutPosition(poseCutoutNode)
                    }
                } else {
                    poseCutoutNode.position.z -= 0.9
                    poseCutoutNode.position.x += 0.9
                    
                }
            }
        }
    
    func resetCutoutPosition(_ node: SCNNode) {
        node.position = SCNVector3(2, 0, -2)
        print("New pose challenge! Position reset.")
        
        var newPoseKey: String
        repeat {
            newPoseKey = targetPoses.keys.randomElement() ?? "defaultPose"
        } while newPoseKey == previousPoseKey
        
        // Update the cutout with the new pose
        if let newPose = targetPoses[newPoseKey] {
            print("New pose challenge: \(newPoseKey)")
            previousPoseKey = newPoseKey // Update the previous pose
            node.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "\(newPoseKey).png") // Update the image
            // isPoseMatched = false // Reset pose matching state
        }
    }

    
    func isPoseMatched(detectedFeatures: [String: Double], targetPose: [String: Double]) -> Bool {
        for (key, targetValue) in targetPose {
            if let detectedValue = detectedFeatures[key] {
                if abs(detectedValue - targetValue) > 10 { // Allow a margin of error
                    return false
                }
            }
        }
        return true
    }
    
//    private func handlePoseObservation(_ observation: VNHumanBodyPoseObservation) {
//        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }
//        
//        let leftWrist = recognizedPoints[.leftWrist]
//        let leftElbow = recognizedPoints[.leftElbow]
//        let leftShoulder = recognizedPoints[.leftShoulder]
//
//        if let wrist = leftWrist?.location,
//        let elbow = leftElbow?.location,
//        let shoulder = leftShoulder?.location {
//        let angle = calculateAngle(pointA: wrist, pointB: elbow, pointC: shoulder)
//        print("Left Arm Angle: \(angle)°")
//        }
//    }
    
    
    func extractFeatures(from observation: VNHumanBodyPoseObservation) -> [String: Double] {
        var features: [String: Double] = [:]

        do {
            let points = try observation.recognizedPoints(.all)
            if let leftElbow = points[.leftElbow], let leftWrist = points[.leftWrist], leftElbow.confidence > 0.5, leftWrist.confidence > 0.5 {
                features["LeftArmAngle"] = calculateAngle(between: leftElbow, and: leftWrist)
            }
            // Add more feature extraction as needed
        } catch {
            print("Error extracting features: \(error)")
        }

        return features
    }
    
    func getPoseObservation() -> VNHumanBodyPoseObservation? {
        // Integrate with Vision pipeline here to get the latest pose
        // Return a VNHumanBodyPoseObservation or nil if no pose is detected
        return nil
    }
    

//    private func calculateAngle(pointA: CGPoint?, pointB: CGPoint?, pointC: CGPoint?) -> CGFloat {
//        guard let pointA = pointA, let pointB = pointB, let pointC = pointC else {
//            print("One or more points are nil")
//            return 0
//        }
//        
//        let vector1 = CGVector(dx: pointB.x - pointA.x, dy: pointB.y - pointA.y)
//        let vector2 = CGVector(dx: pointC.x - pointB.x, dy: pointC.y - pointB.y)
//        let dotProduct = vector1.dx * vector2.dx + vector1.dy * vector2.dy
//        let magnitude1 = sqrt(vector1.dx * vector1.dx + vector1.dy * vector1.dy)
//        let magnitude2 = sqrt(vector2.dx * vector2.dx + vector2.dy * vector2.dy)
//        return acos(dotProduct / (magnitude1 * magnitude2)) * 180 / .pi
//    }
    
    func calculateAngle(between point1: VNRecognizedPoint, and point2: VNRecognizedPoint) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return atan2(dy, dx) * 180 / .pi // Convert radians to degrees
    }
    
    
    
//    private func processImage(_ pixelBuffer: CVPixelBuffer) {
//        //print("hiiiooo")
//        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
//        let request = VNDetectHumanBodyPoseRequest()
//        
//        do {
//            try requestHandler.perform([request])
//            if let results = request.results {
//               // print("Detected \(results.count) pose(s)")
//                if let firstPose = results.first {
//                    currentPoseObservation = firstPose
//                    guard let poseObservation = currentPoseObservation else {
//                        //print("why why why why wy")
//                        return
//                    }
//                    let features = extractFeatures(from: poseObservation)
//                    // predictPose(features: features)
//                    
//               //     print("Pose detected: \(firstPose)")
//                } else {
//                //    print("No pose in results")
//                }
//            } else {
//               // print("No results from request")
//            }
//        } catch {
//            print("Error detecting pose: \(error)")
//        }
//    }
    
    func processImage(_ pixelBuffer: CVPixelBuffer) {
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try requestHandler.perform([request])
            if let results = request.results as? [VNHumanBodyPoseObservation], let firstPose = results.first {
                currentPoseObservation = firstPose
            }
        } catch {
            print("Error detecting pose: \(error)")
        }
    }
    
}
extension GameViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            
            return
        }
        
        processImage(pixelBuffer)
        //print("process image")
    }
}
