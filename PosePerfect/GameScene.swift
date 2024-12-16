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
    
    let boxGeo = SCNBox(width: 1.0, height: 1.0, length: 1.0, chamferRadius: 0.0)
    let sphereGeo = SCNSphere(radius: 0.5)
    
    var timeSinceLaunch: Double = 0
    
    let spawnDist: Float = -30
    let zDeletePos:Float = 5
    var scene: SCNScene = SCNScene(named: "SceneKit Scene.scn") ?? SCNScene()
    let maxXPos: Float = 1.8
    let maxXPosObs: Float = 1.5
    let obsPointMinDist:Float = 1.0
    
    var redMat: SCNMaterial = SCNMaterial()
    var greenMat: SCNMaterial = SCNMaterial()

    var points: Int = 0
    var totalPointsMissed: Int = 0
    var totalObjectsPassed: Int = 0
    
    var moveAmount: Float = 0.2
    let moveAmountChange: Float = 0.03
    
    var obstacleSpawnTime: Double = 3.0
    var minObsSpawnTime: Double = 0.2
    let obsSpawnTimeChange: Double = 0.06
    
    func updatePointLabel() {
        DispatchQueue.main.async { [weak self] in
            self?.pointsLabel.text = "Points: \(self?.points ?? 0)"
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
            Points Earned: \(self?.points ?? 0)
            Points Missed: \(self?.totalPointsMissed ?? 0)
            Obstacles Dodged: \(self?.totalObjectsPassed ?? 0)
            Total Time Survived: \(String(format: "%.2f", self?.timeSinceLaunch ?? 0)) seconds
            """
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        updatePointLabel()
        clearLabels()

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
        redMat = redNode?.geometry?.materials[0] ?? redMat
        greenMat = greenNode?.geometry?.materials[0] ?? greenMat
        
        // Create a box
        let boxNode = createBoxNode(0, 0, spawnDist)
        scene.rootNode.addChildNode(boxNode)
        trackArray.append(boxNode)
        
        print("Obstacle Array Count: \(self.trackArray.count)")
        if let playerNode = self.playerNode {
            print("Player Node Position: \(playerNode.position)")
        } else {
            print("Player Node not found!")
        }
        
        startMotionUpdates()
    }
    

    func createBoxNode(_ x: Float, _ y: Float, _ z: Float) -> SCNNode {
        let boxNode = SCNNode(geometry: boxGeo)
        boxNode.position = SCNVector3(x, y, z)
        boxNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        boxNode.physicsBody?.isAffectedByGravity = false
        boxNode.name = "obstacle"
        
        boxNode.physicsBody?.categoryBitMask = PhysicsCategory.box
        boxNode.physicsBody?.collisionBitMask = PhysicsCategory.player
        boxNode.physicsBody?.contactTestBitMask = PhysicsCategory.player
        
        // Assign the material
        boxNode.geometry?.materials = [redMat].compactMap { $0 }
        
        trackArray.append(boxNode)
        return boxNode
    }

    func createSphereNode(_ x: Float, _ y: Float, _ z: Float) -> SCNNode {
        let sphereNode = SCNNode(geometry: sphereGeo)
        sphereNode.position = SCNVector3(x, y, z)
        sphereNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        sphereNode.physicsBody?.isAffectedByGravity = false
        sphereNode.name = "point"
        
        // Set category, collision, and contact masks
        sphereNode.physicsBody?.categoryBitMask = PhysicsCategory.sphere
        sphereNode.physicsBody?.collisionBitMask = PhysicsCategory.player
        sphereNode.physicsBody?.contactTestBitMask = PhysicsCategory.player
        
        // Assign the material
        sphereNode.geometry?.materials = [greenMat].compactMap { $0 }
        
        trackArray.append(sphereNode)
        return sphereNode
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
            showEndLabels()
            motionManager.stopDeviceMotionUpdates()
        } else if (obj.physicsBody?.categoryBitMask == PhysicsCategory.sphere) {
            points += 1
            //print("Points are now \(points)")
            updatePointLabel()
        }
        
        obj.removeFromParentNode()
        if let index = trackArray.firstIndex(of: obj) {
            trackArray.remove(at: index)
        }
        
        // Handle collision
        //print("Collision detected between \(nodeA.name ?? "NodeA") and \(nodeB.name ?? "NodeB")")
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
            let xDist = Float.random(in: -1.0 * maxXPos...maxXPos)
            let sphereNode = createSphereNode(xDist, 0, spawnDist)
            scene.rootNode.addChildNode(sphereNode)
            
            moveAmount += moveAmountChange
            print ("Move Amount is now \(moveAmount)")

            // Check if enough time has passed to spawn an obstacle
            if time - lastObstacleSpawnTime >= obstacleSpawnTime {
                lastObstacleSpawnTime = time // Update last spawn time
                var newXDist = Float.random(in: -1.0 * maxXPos...maxXPos)
                while abs(xDist - newXDist) < obsPointMinDist {
                    newXDist = Float.random(in: -1.0 * maxXPos...maxXPos)
                }
                let boxNode = createBoxNode(newXDist, 0, spawnDist)
                scene.rootNode.addChildNode(boxNode)
                
                obstacleSpawnTime = max(obstacleSpawnTime - obsSpawnTimeChange, minObsSpawnTime)
                print ("Obstacle Spawn Time is now \(obstacleSpawnTime)")
            }
        }
        
        
    }
    
    func manageTrackObjects() {
        // Update the position of each object on the track
        for node in self.trackArray {
            node.position.z += moveAmount // Move forward towards camera
            //print("Updated Obstacle Position: (\(node.position.x), 0, \(node.position.z))")
            if (node.position.z >= zDeletePos) {
                
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
            totalPointsMissed += 1
        }
            
    }

    func updatePlayerPosition(gravity: CMAcceleration) {
        // Map the tilt to a position
        let tiltFactor: Float = 5.0 // Adjust this factor to control sensitivity
        var xPosition = Float(gravity.x) * tiltFactor
        if (abs(xPosition) > maxXPos) {
            xPosition = maxXPos * xPosition/abs(xPosition)
        }
//        let zPosition = Float(gravity.y) * tiltFactor
        
        // Update the cube's position
        playerNode.position = SCNVector3(xPosition, 0, 0)
        //print("Updated Player Position: (\(xPosition), 0, 0)")
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

// Don't forget to update your Info.plist to allow SceneKit features, if needed.
