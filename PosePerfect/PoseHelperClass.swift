//
//  ARController.swift
//  PosePerfect
//
//  Created by Ayoola Olaosebikan on 12/3/24.
//

import AVFoundation
import UIKit
import Vision

class PoseHelper : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var isPoseMatchedBool: Bool = false
    
    var captureSession: AVCaptureSession!

    let targetPoses: [String: [String: Double]] = [
        "bicep": ["LeftArmAngle": -150, "RightArmAngle": 150],
        "arnold": ["LeftArmAngle": 0, "RightArmAngle": 120],
        "chest": ["LeftArmAngle": 110, "RightArmAngle": 110],
        "tricep": ["LeftArmAngle": 90, "RightArmAngle": 50],
    ]

    var currentPoseObservation: VNHumanBodyPoseObservation?

    let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    
    var previousPoseKey: String?
    var currentPoseKey: String = "bicep"
    
    func start() {
        setupCamera()
        
//        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
//            self.checkPose()
//        }
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

//        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.videoGravity = .resizeAspectFill
//        previewLayer.frame = cameraBackgroundView.bounds
//        cameraBackgroundView.layer.addSublayer(previewLayer)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    func checkPose(targetPose: [String : Double]) -> Bool {
//        guard let currentPoseObservation = currentPoseObservation else {
////            print("No pose detected.")
//            return false;
//        }
        let detectedFeatures = extractFeatures(from: )
        
        return isPoseMatched(detectedFeatures: detectedFeatures, targetPose: targetPose)
    }
    
    func isPoseMatched(detectedFeatures: [String: Double], targetPose: [String: Double]) -> Bool {
        for (key, targetValue) in targetPose {
            if let detectedValue = detectedFeatures[key] {
                print("\(key) and \(detectedValue) and \(targetValue)")
                if abs(detectedValue - targetValue) > 10 { // Allow a margin of error
                    return false
                }
            }
        }
        return true
    }

    var frameCounter = 0
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        if frameCounter % 10 == 0 {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            processImage(pixelBuffer)
        }
    }

    // Pose has random chance to get any pose that wasnt the last one
    func getRandomPose() -> String {
        var newPoseKey: String
        repeat {
            newPoseKey = targetPoses.keys.randomElement() ?? "bicep"
        } while newPoseKey == previousPoseKey

        let newPose = targetPoses[newPoseKey]
        // Update the cutout with the new pose
        if newPose != nil {
            //  print("New pose challenge: \(newPoseKey)")
            currentPoseKey = newPoseKey
            previousPoseKey = newPoseKey // Update the previous pose
//            let img:UIImage = UIImage(named: "\(newPoseKey).png")! // todo DO SOMETHING HERE
            isPoseMatchedBool = false // Reset pose matching state
        }
        
        return currentPoseKey
    }
}

extension PoseHelper {
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
                        print(firstPose)
                        self.analyzePose(from: firstPose)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.currentPoseObservation = nil
//                        print("No pose detected.")
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

extension PoseHelper {
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
