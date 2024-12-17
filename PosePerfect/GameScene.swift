//
//  GameScene.swift
//  PosePerfect
//
//  Created by Ayoola Olaosebikan on 12/16/24.
//

import UIKit
import SceneKit
import CoreMotion

class GameScene: UIViewController, SCNPhysicsContactDelegate {
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var annoucementLabel: UILabel!
    @IBOutlet weak var statsLabel: UILabel!

    // Create an SCNView
    var sceneView: SCNView!
    var labelContainer: UIView!
    
    var playerNode: SCNNode!
    let motionManager = CMMotionManager()
    
    var trackArray: [SCNNode] = []
    var poseArray: [String] = []
    
    let boxGeo = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
    let sphereGeo = SCNSphere(radius: 0.5)
    let planeWidth: Float = 5.0
    var planeGeo = SCNPlane(width: 5.0, height: 5.0)
    
    var timeSinceLaunch: Double = 0
    
    let spawnDist: Float = -50
    let zDeletePos:Float = 5
    var scene: SCNScene = SCNScene(named: "SceneKit Scene.scn") ?? SCNScene()
    let maxXPos: Float = 1.8
    let maxXPosObs: Float = 1.5
    let obsPointMinDist:Float = 1.0
    
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
    
    let poseDetection: PoseHelper = PoseHelper()
    
    var matDict: [String : SCNMaterial] = [:]
    
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
        
        poseDetection.start()
        
        planeGeo = SCNPlane(width: CGFloat(planeWidth), height: CGFloat(planeWidth))
        
        updatePointLabel()
        clearLabels()
        tutorialText()

        sceneView = SCNView(frame: self.view.bounds)
        self.view.addSubview(sceneView)

        sceneView.allowsCameraControl = false
        sceneView.showsStatistics = true
        
        boxGeo.materials = [createDefaultMaterial()]
        sphereGeo.materials = [createDefaultMaterial()]

        sceneView.scene = scene
        
        //Setup UI
        labelContainer = UIView()
        labelContainer.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(labelContainer)

        // Add constraints for the container
//        NSLayoutConstraint.activate([
//            labelContainer.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 20),
//            labelContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20),
//            labelContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20)
//        ])
        
        labelContainer.addSubview(pointsLabel)
        labelContainer.addSubview(statsLabel)
        labelContainer.addSubview(annoucementLabel)
        
        setupScene() // Pass the loaded scene to setupScene
    }

    func setupScene() {
        // Set the physics world delegate
        scene.physicsWorld.contactDelegate = self
        
        playerNode = scene.rootNode.childNode(withName: "player", recursively: true)
        let redNode = scene.rootNode.childNode(withName: "red", recursively: true)
        let greenNode = scene.rootNode.childNode(withName: "green", recursively: true)
        let glassNode = scene.rootNode.childNode(withName: "glass", recursively: true)
        redMat = redNode?.geometry?.materials[0] ?? redMat
        greenMat = greenNode?.geometry?.materials[0] ?? greenMat
        glassMat = glassNode?.geometry?.materials[0] ?? glassMat
        
        // Create a box
//        let planeNode = createPlaneNode(0, planeWidth/2, spawnDist)
//        scene.rootNode.addChildNode(planeNode)
//        
//        
//        print("Obstacle Array Count: \(self.trackArray.count)")
        if let playerNode = self.playerNode {
            print("Player Node Position: \(playerNode.position)")
        } else {
            print("Player Node not found!")
        }
        
        startMotionUpdates()
    }
    
    func createPlaneNode(_ x: Float, _ y: Float, _ z: Float) -> SCNNode {
        let planeNode = SCNNode(geometry: SCNPlane(width: CGFloat(planeWidth), height: CGFloat(planeWidth)))
        planeNode.position = SCNVector3(x, y, z)
        planeNode.rotation = SCNVector4(0.0, 90.0, 0.0, 0.0)
        planeNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        planeNode.physicsBody?.isAffectedByGravity = false
        planeNode.name = "obstacle"
        
        planeNode.physicsBody?.categoryBitMask = PhysicsCategory.box
        planeNode.physicsBody?.collisionBitMask = PhysicsCategory.player
        planeNode.physicsBody?.contactTestBitMask = PhysicsCategory.player
        
        var poseName: String = poseDetection.getRandomPose() //fallback value
        
        var material = matDict[poseName]
        if material == nil {
            material = glassMat.copy() as? SCNMaterial
            let maskImage = UIImage(named: poseName + "Mask.png")
            material!.transparent.contents = maskImage
            material!.blendMode = .alpha
            material!.transparencyMode = .rgbZero
            matDict[poseName] = material
        }
        
        print("Pose changed to " + poseName)
        
        planeNode.geometry?.materials = [material].compactMap { $0 }
        
        poseArray.append(poseName)
        trackArray.append(planeNode)
        return planeNode
    }
    
    struct PhysicsCategory {
        static let player: Int = 1 << 0    // 1 (binary: 0001)
        static let box: Int = 1 << 1       // 2 (binary: 0010)
        static let sphere: Int = 1 << 2    // 4 (binary: 0100)
    }

    // SCNPhysicsContactDelegate method
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        var player: SCNNode
        var obj: SCNNode
        
        if (nodeA.physicsBody?.categoryBitMask == PhysicsCategory.player) {
            player = nodeA
            obj = nodeB
        } else {
            player = nodeB
            obj = nodeA
        }
        
        if (obj.physicsBody?.categoryBitMask == PhysicsCategory.box) {
            print("collision detected")
            let poseName = poseArray.first!
            let poseData = poseDetection.targetPoses[poseName]!
            print("checking pose: ", poseName)
            print(poseData)
            if (poseDetection.checkPose(targetPose: poseData)) {
                points += 1
                updatePointLabel()
                obj.physicsBody = nil
                return
            }
            else {
                triggerGameOver()
            }
            
        }
        
//        obj.removeFromParentNode()
//        if let index = trackArray.firstIndex(of: obj) {
//            trackArray.remove(at: index)
//        }
        
        // Handle collision
        //print("Collision detected between \(nodeA.name ?? "NodeA") and \(nodeB.name ?? "NodeB")")
    }
    
    func triggerGameOver() {
        showEndLabels()
        motionManager.stopDeviceMotionUpdates()
    }
    
    func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.05
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                timeSinceLaunch += motionManager.deviceMotionUpdateInterval
                generateTrackObjects(timeSinceLaunch)
                
                self.updatePlayerPosition(gravity: data.gravity)
                self.manageTrackObjects()
                
                if (!tutorialShown && (timeSinceLaunch > Double(tutorialTextTime))) {
                    clearLabels()
                }
            }
        }
    }
    
    var lastPointSpawnTime: Double = 0
    var lastObstacleSpawnTime: Double = 0

    func generateTrackObjects(_ time: Double) {
        let pointSpawnTime: Double = obstacleSpawnTime/2.0

        // Check if enough time has passed to spawn a point
        if time - lastPointSpawnTime >= pointSpawnTime {
            lastPointSpawnTime = time // Update last spawn time
//            let xDist = Float.random(in: -1.0 * maxXPos...maxXPos)
//            let sphereNode = createSphereNode(xDist, 0, spawnDist)
//            scene.rootNode.addChildNode(sphereNode) // spawn point orb
            
            moveAmount += moveAmountChange
            print ("Move Amount is now \(moveAmount)")

            if time - lastObstacleSpawnTime >= obstacleSpawnTime {
                lastObstacleSpawnTime = time // Update last spawn time
                let planeNode = createPlaneNode(0.0, planeWidth/2, spawnDist)
                scene.rootNode.addChildNode(planeNode)
                
                obstacleSpawnTime = max(obstacleSpawnTime - obsSpawnTimeChange, minObsSpawnTime)
                print ("Obstacle Spawn Time is now \(obstacleSpawnTime)")
            }
        }
    }
    
    func manageTrackObjects() {
        // Update the position of each object on the track
        for (_, node) in self.trackArray.enumerated() {
            node.position.z += moveAmount // Move forward towards camera
            //print("Updated Obstacle Position: (\(node.position.x), 0, \(node.position.z))")
            if (node.position.z >= zDeletePos) {
                if (!poseArray.isEmpty) {poseArray.removeFirst()} // this might be remove last actually
                node.removeFromParentNode()
                //print("Removed node")
            }
        }
        //print("Obj count: \(self.trackArray.count)")
        
        // Remove references to removed nodes
        trackArray.removeAll { $0.position.z >= zDeletePos }
    }
    
    func processDeletedObj(_ node: SCNNode) {
        if (node.physicsBody?.categoryBitMask == 1) {
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
    
    func createBGMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.3, alpha: 1.0)
        material.specular.contents = UIColor(white: 1.0, alpha: 1.0)
        material.shininess = 0.0
        material.ambient.contents = UIColor(white: 0.2, alpha: 1.0)
        return material
    }
    
    func createGlassMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.clear
        material.specular.contents = UIColor.white
        material.shininess = 100.0
        material.transparency = 0.5
        material.blendMode = .alpha
        material.reflective.contents = UIColor.white
        material.isDoubleSided = true
        return material
    }
}


