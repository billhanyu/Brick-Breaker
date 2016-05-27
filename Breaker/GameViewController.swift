//
//  GameViewController.swift
//  Breaker
//
//  Created by Bill Yu on 5/22/16.
//  Copyright (c) 2016 Bill Yu. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit

enum ColliderType: Int {
    case Ball = 0b1
    case Barrier = 0b10
    case Brick = 0b100
    case Paddle = 0b1000
}

class GameViewController: UIViewController {
    
    var scnView: SCNView!
    var game = GameHelper.sharedInstance
    var scnScene: SCNScene!
    var horizontalCameraNode: SCNNode!
    var verticalCameraNode: SCNNode!
    var ballNode: SCNNode!
    var paddleNode: SCNNode!
    var lastContactNode: SCNNode!
    var touchX: CGFloat = 0
    var paddleX: Float = 0
    var floorNode: SCNNode!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScene()
        setupNodes()
        setupSounds()
    }
    
    func setupScene() {
        scnView = self.view as! SCNView
        scnView.delegate = self
        scnScene = SCNScene(named: "Breaker.scnassets/Scenes/Game.scn")
        scnView.scene = scnScene
        scnScene.physicsWorld.contactDelegate = self
    }
    
    func setupNodes() {
        scnScene.rootNode.addChildNode(game.hudNode)
        horizontalCameraNode = scnScene.rootNode.childNodeWithName("HorizontalCamera", recursively: true)!
        verticalCameraNode = scnScene.rootNode.childNodeWithName("VerticalCamera", recursively: true)!
        ballNode = scnScene.rootNode.childNodeWithName("Ball", recursively: true)!
        paddleNode = scnScene.rootNode.childNodeWithName("Paddle", recursively: true)!
        ballNode.physicsBody?.contactTestBitMask = ColliderType.Barrier.rawValue | ColliderType.Brick.rawValue | ColliderType.Paddle.rawValue
        floorNode = scnScene.rootNode.childNodeWithName("Floor", recursively: true)!
        verticalCameraNode.constraints = [SCNLookAtConstraint(target: floorNode)]
        horizontalCameraNode.constraints = [SCNLookAtConstraint(target: floorNode)]
    }
    
    func setupSounds() {
        game.loadSound("Paddle", fileNamed: "Breaker.scnassets/Sounds/Paddle.wav")
        game.loadSound("Block0", fileNamed: "Breaker.scnassets/Sounds/Block0.wav")
        game.loadSound("Block1", fileNamed: "Breaker.scnassets/Sounds/Block1.wav")
        game.loadSound("Block2", fileNamed: "Breaker.scnassets/Sounds/Block2.wav")
        game.loadSound("Barrier", fileNamed: "Breaker.scnassets/Sounds/Barrier.wav")
        game.loadSound("Over", fileNamed: "Breaker.scnassets/Sounds/GameOver.wav")
    }
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        let deviceOrientation = UIDevice.currentDevice().orientation
        switch (deviceOrientation) {
        case .Portrait:
            scnView.pointOfView = verticalCameraNode
        default:
            scnView.pointOfView = horizontalCameraNode
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let location = touch.locationInView(scnView)
            touchX = location.x
            paddleX = paddleNode.position.x
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        for touch in touches {
            let location = touch.locationInView(scnView)
            paddleNode.position.x = paddleX + (Float(location.x - touchX) * 0.1)
            
            if paddleNode.position.x > 4.5 {
                paddleNode.position.x = 4.5
            } else if paddleNode.position.x < -4.5 {
                paddleNode.position.x = -4.5
            }
        }
        verticalCameraNode.position.x = paddleNode.position.x
        horizontalCameraNode.position.x = paddleNode.position.x
    }
}

extension GameViewController: SCNSceneRendererDelegate {
    func renderer(renderer: SCNSceneRenderer, updateAtTime time: NSTimeInterval) {
        game.updateHUD()
    }
}

extension GameViewController: SCNPhysicsContactDelegate {
    func physicsWorld(world: SCNPhysicsWorld, didBeginContact contact: SCNPhysicsContact) {
        var contactNode: SCNNode!
        if contact.nodeA.name == "Ball" {
            contactNode = contact.nodeB
        } else {
            contactNode = contact.nodeA
        }
        if lastContactNode != nil && lastContactNode == contactNode {
            return
        }
        lastContactNode = contactNode
        
        if contactNode.physicsBody?.categoryBitMask == ColliderType.Barrier.rawValue {
            game.playSound(scnScene.rootNode, name: "Barrier")
            if contactNode.name == "Bottom" {
                game.lives -= 1
                if game.lives == 0 {
                    game.playSound(scnScene.rootNode, name: "Over")
                    game.saveState()
                    game.reset()
                }
            }
        }
        
        if contactNode.physicsBody?.categoryBitMask == ColliderType.Brick.rawValue {
            game.playSound(scnScene.rootNode, name: "Block0")
            game.score += 1
            contactNode.hidden = true
            contactNode.runAction(SCNAction.waitForDurationThenRunBlock(120) {
                (node: SCNNode!) -> Void in
                node.hidden = false
            })
        }
        
        if contactNode.physicsBody?.categoryBitMask == ColliderType.Paddle.rawValue {
            game.playSound(scnScene.rootNode, name: "Paddle")
            if contactNode.name == "Left" {
                ballNode.physicsBody!.velocity.xzAngle -= (convertToRadians(20))
            }
            if contactNode.name == "Right" {
                ballNode.physicsBody!.velocity.xzAngle += (convertToRadians(20))
            }
        }
        
        ballNode.physicsBody?.velocity.length = 3.0
    }
}