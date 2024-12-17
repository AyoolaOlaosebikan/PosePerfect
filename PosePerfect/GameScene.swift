//
//  GameScene.swift
//  PosePerfect
//
//  Created by Ayoola Olaosebikan on 12/16/24.
//

import AVFoundation
import CoreMotion
import SceneKit
import UIKit
import Vision

class GameScene: UIViewController, SCNPhysicsContactDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet var pointsLabel: UILabel!
    @IBOutlet var annoucementLabel: UILabel!
    @IBOutlet var statsLabel: UILabel!
    @IBOutlet weak var poseInfoLabel: UILabel!
    
    @IBOutlet var cameraBackgroundView: UIView!
    @IBOutlet var sceneView: SCNView!

    // Create an SCNView
    // var sceneView: SCNView!
    var labelContainer: UIView!

    var playerNode: SCNNode!
    let motionManager = CMMotionManager()
    var figureNode: SCNNode!

    //var trackArray: [SCNNode] = []
    var currentObstacleNode: SCNNode?

    let boxGeo = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
    let sphereGeo = SCNSphere(radius: 0.5)
    let planeWidth: Float = 5.0
    var planeGeo = SCNPlane(width: 5.0, height: 5.0)

    var timeSinceLaunch: Double = 0

    let spawnDist: Float = -50
    let zDeletePos: Float = 0
    var scene: SCNScene = SCNScene(named: "SceneKit Scene.scn") ?? SCNScene()
    let maxXPos: Float = 1.8
    let maxXPosObs: Float = 1.5
    let obsPointMinDist: Float = 1.0

    var redMat: SCNMaterial = SCNMaterial()
    var greenMat: SCNMaterial = SCNMaterial()
    var glassMat: SCNMaterial = SCNMaterial()

    var points: Int = 0
    var totalPointsMissed: Int = 0
    var totalObjectsPassed: Int = 0

    var moveAmount: Float = 0.2
    let moveAmountChange: Float = 0.02

    var obstacleSpawnTime: Double = 5.0
    var minObsSpawnTime: Double = 0.2
    let obsSpawnTimeChange: Double = 0.06

    let tutorialTextTime: Float = 5.0
    let tutorialShown: Bool = false

    var captureSession: AVCaptureSession!

    var isPoseMatchedBool: Bool = false

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

    func updatePointLabel() {
        DispatchQueue.main.async { [weak self] in
            self?.pointsLabel.text = "\(self?.points ?? 0) Perfect Pose\(self?.points == 1 ? "" : "s")" + String(repeating: "!", count: (self?.points ?? 0) / 5)
        }
    }

    func tutorialText() {
        DispatchQueue.main.async { [weak self] in
            self?.statsLabel.text = """
            You gotta strut your stuff on the red carpet!
            Do the right pose to fit through the hole.
            The more holes you pass, the faster you go.
            Can you pose perfect?
            Or are you just a poser?
            """
        }
    }

    func clearLabels() {
        DispatchQueue.main.async { [weak self] in
            self?.annoucementLabel.text = ""
            self?.statsLabel.text = ""
        }
    }

    func showEndLabels() {
        DispatchQueue.main.async { [weak self] in
            self?.annoucementLabel.text = "You crashed!"
            self?.statsLabel.text = """
            Number of Perfect Poses: \(self?.totalObjectsPassed ?? 0)
            Total Posing Time: \(String(format: "%.2f", self?.timeSinceLaunch ?? 0)) seconds
            """
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        planeGeo = SCNPlane(width: CGFloat(planeWidth), height: CGFloat(planeWidth))

        updatePointLabel()
        clearLabels()
        tutorialText()

        // sceneView = SCNView(frame: self.view.bounds)
        view.addSubview(sceneView)

        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = true
        sceneView.backgroundColor = .clear

        boxGeo.materials = [createDefaultMaterial()]
        sphereGeo.materials = [createDefaultMaterial()]

        sceneView.scene = scene

        // Setup UI
        labelContainer = UIView()
        labelContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(labelContainer)

        // Add constraints for the container
//        NSLayoutConstraint.activate([
//            labelContainer.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 20),
//            labelContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
//            labelContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20)
//        ])

        labelContainer.addSubview(pointsLabel)
        labelContainer.addSubview(annoucementLabel)

        setupScene() // Pass the loaded scene to setupScene

        setupCamera()
//        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
//            self.updateGame()
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

//    func updateGame() {
//        guard let poseCutoutNode = sceneView.scene?.rootNode.childNode(withName: "PoseCutout", recursively: true) else { return }
//        guard let currentPoseObservation = currentPoseObservation else {
//               print("No pose detected. Keeping cutout stationary.")
//               return
//           }
//
//        poseCutoutNode.position.z += 0.012
//        poseCutoutNode.position.x -= 0.012
//       // if let currentPoseObservation = currentPoseObservation {
//
//
//            // print("we here")
//            let detectedFeatures = extractFeatures(from: currentPoseObservation)
//           //print("Current Pose Key: \(currentPoseKey)")
//            if let targetPose = targetPoses[currentPoseKey] {
//               // print("in there")
//                if isPoseMatched(detectedFeatures: detectedFeatures, targetPose: targetPose) {
//                    // Move the cutout closer
//                    isPoseMatchedBool = true
//                    print("Pose matched! Moving cutout.")
//                } else {
//                    //                    poseCutoutNode.position.z -= 0.1
//                    //                    poseCutoutNode.position.x -= 0.1
//                    isPoseMatchedBool = false
//                    print("Pose not matched. Try again.")
//            //    }
//            }
//        }
//
//        // Reset position or advance to next level
//        if poseCutoutNode.position.z > 0.2 {
//            if isPoseMatchedBool {
//                if poseCutoutNode.position.z > 1 {
//                    resetCutoutPosition(poseCutoutNode)
//                }
//            } else {
//                poseCutoutNode.position.z -= 0.9
//                poseCutoutNode.position.x += 0.9
//            }
//        }
//    }

    var frameCounter = 0
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        if frameCounter % 10 == 0 {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            processImage(pixelBuffer)
        }
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

    func setupScene() {
        // Set the physics world delegate
        scene.physicsWorld.contactDelegate = self

        playerNode = scene.rootNode.childNode(withName: "player", recursively: true)
        if let modelScene = SCNScene(named: "The_Chosen_One_Animator_VS_Animation.usdz"),
           let figureNode = modelScene.rootNode.childNodes.first {
            figureNode.position = SCNVector3(0, 2, 0) // Set position
            figureNode.scale = SCNVector3(0.06, 0.06, 0.06) // Adjust scale if needed
            scene.rootNode.addChildNode(figureNode)
        }
        let redNode = scene.rootNode.childNode(withName: "red", recursively: true)
        let greenNode = scene.rootNode.childNode(withName: "green", recursively: true)
        let glassNode = scene.rootNode.childNode(withName: "glass", recursively: true)
        redMat = redNode?.geometry?.materials[0] ?? redMat
        greenMat = greenNode?.geometry?.materials[0] ?? greenMat
        glassMat = glassNode?.geometry?.materials[0] ?? glassMat

        // Create a box
        generateTrackObject()

       // print("Obstacle Array Count: \(trackArray.count)")
        if let playerNode = playerNode {
            print("Player Node Position: \(playerNode.position)")
        } else {
            print("Player Node not found!")
        }

        startMotionUpdates()
    }

    func createPlaneNode(_ x: Float, _ y: Float, _ z: Float, randomPoseKey: String) -> SCNNode {
        let planeNode = SCNNode(geometry: planeGeo)
        planeNode.position = SCNVector3(x, y, z)
        planeNode.rotation = SCNVector4(0.0, 90.0, 0.0, 0.0)
        planeNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        planeNode.physicsBody?.isAffectedByGravity = false
        planeNode.name = "obstacle"
        planeNode.scale = SCNVector3(4.0, 4.0, 1.0)

        planeNode.physicsBody?.categoryBitMask = PhysicsCategory.box
        planeNode.physicsBody?.collisionBitMask = PhysicsCategory.player
        planeNode.physicsBody?.contactTestBitMask = PhysicsCategory.player

//        let randomPoseKey = targetPoses.keys.randomElement() ?? "front_biceps"
//        currentPoseKey = randomPoseKey // Update currentPoseKey for consistency

        // Use the selected pose key to fetch the corresponding cutout image
        let imageName = "\(randomPoseKey).png"
        if let maskImage = UIImage(named: imageName) {
            let material = glassMat
            material.diffuse.contents = maskImage
            material.transparent.contents = maskImage
            material.blendMode = .alpha
            material.transparencyMode = .rgbZero

            // Apply the material to the plane
            planeNode.geometry?.materials = [material].compactMap { $0 }
        } else {
            // Fallback to default glass material if the image is missing
            print("Warning: Image \(imageName) not found. Using default material.")
            planeNode.geometry?.materials = [glassMat].compactMap { $0 }
        }

        // Assign the material

       // trackArray.append(planeNode)
        return planeNode
    }

    struct PhysicsCategory {
        static let player: Int = 1 << 0 // 1 (binary: 0001)
        static let box: Int = 1 << 1 // 2 (binary: 0010)
        static let sphere: Int = 1 << 2 // 4 (binary: 0100)
    }

    // SCNPhysicsContactDelegate method
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        var player: SCNNode
        var obj: SCNNode

        if nodeA.physicsBody?.categoryBitMask == PhysicsCategory.player {
            player = nodeA
            obj = nodeB
        } else {
            player = nodeB
            obj = nodeA
        }

        if obj.physicsBody?.categoryBitMask == PhysicsCategory.box {
            // Ensure we have the current pose observation for comparison
            if let currentPoseObservation = currentPoseObservation {
                let detectedFeatures = extractFeatures(from: currentPoseObservation)

                // Check if the current pose matches the target pose
                if let targetPose = targetPoses[currentPoseKey], isPoseMatched(detectedFeatures: detectedFeatures, targetPose: targetPose) {
                    // Pose matches: Increase points and update the label
                    print("Pose Matched! Awarding points.")
                    points += 1
                    updatePointLabel()
                    generateTrackObject()
                } else {
                    // Pose does not match: Trigger game over
                    print("Pose did not match. moving back")
                   // triggerGameOver()
                    return
                }
            } else {
                // If no pose is detected, trigger game over
                print("No pose detected. moving back")
                
               // triggerGameOver()
                return
            }

            // Remove the cutout node from the scene
            obj.removeFromParentNode()
//            if let index = trackArray.firstIndex(of: obj) {
//                trackArray.remove(at: index)
//            }
//            currentObstacleNode.remove()

            points += 1
            updatePointLabel()
        }

        obj.removeFromParentNode()
//        if let index = trackArray.firstIndex(of: obj) {
//            trackArray.remove(at: index)
//        }

        // Handle collision
        // print("Collision detected between \(nodeA.name ?? "NodeA") and \(nodeB.name ?? "NodeB")")
    }

    func triggerGameOver() {
        showEndLabels()
        motionManager.stopDeviceMotionUpdates()
    }

    func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.05
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let data = data else { return }
                timeSinceLaunch += motionManager.deviceMotionUpdateInterval
               // generateTrackObjects(timeSinceLaunch)

                self.updatePlayerPosition(gravity: data.gravity)
                self.manageTrackObjects()

                if !tutorialShown && (timeSinceLaunch > Double(tutorialTextTime)) {
                    clearLabels()
                }
            }
        }
    }

    var lastPointSpawnTime: Double = 0
    var lastObstacleSpawnTime: Double = 0

    func generateTrackObject() {
        let randomPoseKey = targetPoses.keys.randomElement() ?? "front_biceps"
        currentPoseKey = randomPoseKey // Update currentPoseKey for consistency
        let planeNode = createPlaneNode(0, 7, spawnDist, randomPoseKey: randomPoseKey)
        scene.rootNode.addChildNode(planeNode)
        currentObstacleNode = planeNode
        //trackArray.append(planeNode)
    }

    func manageTrackObjects() {
        // Move the current cutout forward
        //print("here")
        currentObstacleNode?.position.z += moveAmount
        
        if (currentObstacleNode?.position.z)! >= -10 {
            currentObstacleNode?.scale = SCNVector3(2.0,2.0,1.0)
            currentObstacleNode?.position = SCNVector3(0, 4, (currentObstacleNode?.position.z)!)
        }

        // Check if the cutout passed the player
        if let cutout = currentObstacleNode, cutout.position.z >= zDeletePos {
            currentObstacleNode?.position.z -= 10
        }
    }

    func processDeletedObj(_ node: SCNNode) {
        if node.physicsBody?.categoryBitMask == 1 {
            totalObjectsPassed += 1
        } else {
//            totalPointsMissed += 1
        }
    }

    func updatePlayerPosition(gravity: CMAcceleration) {
        // do stuff
    }

    func createDefaultMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.8, alpha: 1.0)
        material.specular.contents = UIColor(white: 1.0, alpha: 1.0)
        material.shininess = 0.0
        material.ambient.contents = UIColor(white: 0.2, alpha: 1.0)
        return material
    }
}

extension GameScene {
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
                        self.poseInfoLabel.isHidden = true
                    }
                } else {
                    DispatchQueue.main.async {
                        self.currentPoseObservation = nil
                        //print("No pose detected.")
                        self.poseInfoLabel.isHidden = false
                        self.poseInfoLabel.text = "No pose detected. Put your entire body into the frame of the camera."
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

extension GameScene {
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
