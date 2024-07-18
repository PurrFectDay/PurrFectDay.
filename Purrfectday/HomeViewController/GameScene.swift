import UIKit
import SpriteKit
import GameplayKit
import AVFoundation

class GameScene: SKScene {
    var border = SKShapeNode()
    weak var gameDelegate: GameSceneDelegate!
    
    // Define physics categories
    struct PhysicsCategory {
        static let none: UInt32 = 0
        static let cat: UInt32 = 0b1
        static let furniture: UInt32 = 0b10
    }
    
    var progress: Int?
    
    // 타일 이미지
    var wallTileTexture = SKTexture(imageNamed: "wall_01_01")
    var moldingTileTexture = SKTexture(imageNamed: "molding_01_01")
    var floorTileTexture = SKTexture(imageNamed: "wall_01_01")
    var windowTileTexture = SKTexture(imageNamed: "window_01_01")
    
    var catSprite = SKSpriteNode()
    var catSize = CGSize(width: 40, height: 40)
    var catTouchedSize = CGSize(width: 50, height: 50)
    
    var bubbleSprite = SKSpriteNode()
    let bubbleSpriteList = ["bubble01", "bubble02", "bubble03", "bubble04", "bubble05", "bubble06", "bubble07", "bubble08", "bubble09"]
    var bubbleTextList: [String] = []
    
    var dirtySprite = SKSpriteNode()
    let dirtySpriteList = ["dirty01", "dirty02", "dirty03", "dirty04", "dirty05"]
    var dirtyCount: Int = DatabaseUtils.shared.dirtyCount ?? 0
    var dirtySpriteData: [String: [String: Any]] = DatabaseUtils.shared.dirtySpriteData
    
    var roomSpriteList: [String: [Item]] = DatabaseUtils.shared.shopList
    
    var saveTime: TimeInterval = 0
    var animationTime: TimeInterval = 0
    
    // AVAudioPlayer 객체 선언
    var audioPlayer: AVAudioPlayer?
    var catMoveAction: SKAction?
    
    override func didMove(to view: SKView) {
        resetScene()
        
        // PanGestureRecognizer 추가
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
        
        // 고양이 앉기 애니메이션 시작
        startCatSittingAnimation()
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        moveTime(from: currentTime)
        talkMove()
    }
    
    func resetScene() {
        // Remove all existing nodes
        self.removeAllChildren()
        self.removeAllActions()

        // Reset all data
        DatabaseUtils.shared.setRoomDirty(completion: { intData, listData in
            self.dirtyCount = intData
            self.dirtySpriteData = listData
        })
        DatabaseUtils.shared.getShop(completion: { data in
            self.roomSpriteList = data!
        })
        DatabaseUtils.shared.getBubble(completion: { data in
            self.bubbleTextList = data
        })

        // Recreate the scene
        createTileMap()
        spriteUI()
        roomUI()
        dirtyUI()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            let touchArray = self.nodes(at: location)
            
            // 고양이 클릭 시 크기 변화
            if touchArray.first?.name == "catSprite" {
                catSprite.adjustAspectFill(to: catTouchedSize)
                
                bubbleSprite.removeFromParent()
                
//                bubbleSprite = SKSpriteNode(imageNamed: bubbleSpriteList[Int.random(in: 0...bubbleSpriteList.count-1)])
//                bubbleSprite.size = CGSize(width: 100, height: 100)
//                bubbleSprite.position = CGPoint(x: catSprite.position.x, y: catSprite.position.y)
//                bubbleSprite.zPosition = 10
//                addChild(bubbleSprite)
                
                bubbleSprite.removeFromParent()
                
                
                let userDefaults = UserDefaults.standard
                var bubbles: [String] = []
                
                if self.bubbleTextList.isEmpty {
                    if userDefaults.hasConnectedToday() {
    //                    print("User has connected today.")
                        // Handle the case where the user has already connected today
                        bubbles.append("널 또 봐서 기뻐")
                        
                    } else {
    //                    print("User has not connected today.")
                        // Handle the case where this is the user's first connection today
                        bubbles.append("안녕")
                        bubbles.append("반가워")
                        bubbles.append("좀 더 자주 보고 싶어")
                        bubbles.append("오늘도 와줬구나 >ㅅ<")
                        bubbles.append("오늘도 만나서 너무 기뻐!")
                        bubbles.append("널 좀 더 자주 보고 싶어")
                        bubbles.append("네가 안 와서 너무 외로웠어")
                        bubbles.append("네가 없어서 너무 심심했어!")
                    }
                    
                    bubbles.append("화이팅")
                    bubbles.append("조금씩 나아가면 돼!")
                    bubbles.append("꾸준히 하다 보면 \n목표를 이룰 수 있을 거야!")
                    
                    if 0 < self.progress! && self.progress! <= 20 {
                        bubbles.append("시작이 반이래~!")
                    }
                    
                    if self.progress! < 50 {
                        bubbles.append("조금씩 나아가면 돼!")
                    }
                    
                    if self.progress! >= 70 && self.progress! >= 90 {
                        bubbles.append("좀 더 하면 되겠는 걸!?")
                        bubbles.append("와우! 목표 달성 직전이야")
                        bubbles.append("얼마 안 남았어!  끝까지 도전해보자")
                    }
                }
                
                bubbles = bubbles + self.bubbleTextList
                let randomBubbleText = bubbles.randomElement()
                makeBubbleSprite(with: randomBubbleText!)
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                    self.bubbleSprite.size = CGSize(width: 0, height: 0)
                }
            }
            
            // 쓰레기 클릭 시 청소
            if let dirtyNode = touchArray.first, dirtyNode.name?.starts(with: "dirtySprite") == true {
                
                DatabaseUtils.shared.updatePoint(change: -30, cancel: false) { change in
                    if change >= 0 {
                        if let index = Int(dirtyNode.name!.suffix(1)) {
                            dirtyNode.removeFromParent()
                            
                            // 청소 후 청결도와 sprite data 업데이트(sprite 제거)
                            DatabaseUtils.shared.updateRoomDirty(dirty: self.dirtyCount, spriteList: self.dirtySpriteData, index: index) { degreeData, spriteData in
                                self.dirtyCount = degreeData
                                self.dirtySpriteData = spriteData
                                
                                // 포인트 업데이트
                                self.gameDelegate?.updatePoints(change)
                            }
                        } else {
                            print("Error: Could not extract index from dirtySprite name")
                        }
                    }
                    else if change == -3 {
                        self.gameDelegate?.showToast(message: "포인트가 부족합니다.")
                    }
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        catSprite.adjustAspectFill(to: catSize)
    }
    
    // 팬 제스처 핸들러
    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        let location = sender.location(in: view)
        let skViewLocation = convertPoint(fromView: location)
        
        switch sender.state {
        case .began:
            if catSprite.contains(skViewLocation) {
                // 문지르기 효과음 재생
                SoundEffectPlayer.shared.play(fileName: "purring")
            }
            catSprite.adjustAspectFill(to: catSize)
        case .changed:
            if catSprite.contains(skViewLocation) {
                emitterUI()
            }
            catSprite.adjustAspectFill(to: catTouchedSize)
        case .ended:
            if catSprite.contains(skViewLocation) {
                // 문지르기 효과음 정지
                SoundEffectPlayer.shared.stop(filename: "purring")
            }
            catSprite.adjustAspectFill(to: catSize)
        default:
            break
        }
    }
    
    func createTileMap() {
        
        // 배치한 벽지 / 몰딩 / 바닥이 있는 경우 텍스처 재설정
        for i in 0 ..< (roomSpriteList["wall"]?.count ?? 1) {
            if roomSpriteList["wall"]?[i].isPlaced == true {
                wallTileTexture = SKTexture(imageNamed: roomSpriteList["wall"]?[i].imageName ?? "wall_01_01")
            }
        }
        
        for i in 0 ..< (roomSpriteList["molding"]?.count ?? 1) {
            if roomSpriteList["molding"]?[i].isPlaced == true {
                moldingTileTexture = SKTexture(imageNamed: roomSpriteList["molding"]?[i].imageName ?? "molding_01_01")
            }
        }
        
        for i in 0 ..< (roomSpriteList["floor"]?.count ?? 1) {
            if roomSpriteList["floor"]?[i].isPlaced == true {
                floorTileTexture = SKTexture(imageNamed: roomSpriteList["floor"]?[i].imageName ?? "floor_01_01")
            }
        }
        
        // 타일 크기
        let wallTileSize = wallTileTexture.size()
        let moldingTileSize = CGSize(width: moldingTileTexture.size().width, height: moldingTileTexture.size().height)
        let floorTileSize = floorTileTexture.size()
        
        // 타일 노드 생성 및 배치
        let middleY = frame.midY
        let middleX = frame.midX
        
        // 타일맵 노드 생성
        let tileMapNode = SKNode()
        tileMapNode.zPosition = -10  // 배경으로 설정하기 위해 zPosition을 낮게 설정
        
        // 좌우로 molding 타일 배치
        var currentX = frame.minX
        
        while currentX < frame.maxX {
            let moldingTileNode = SKSpriteNode(texture: moldingTileTexture)
            moldingTileNode.position = CGPoint(x: currentX + moldingTileSize.width / 2, y: middleY)
            moldingTileNode.zPosition = -5
            tileMapNode.addChild(moldingTileNode)
            currentX += moldingTileSize.width
        }
        
        // 좌우로 wallTile, floorTile 배치
        let numberOfColumns = Int(frame.width / wallTileSize.width)
        
        for i in 0...numberOfColumns {
            let xOffset = CGFloat(i) * wallTileSize.width
            
            // 중앙 열 및 오른쪽 열
            addTiles(to: tileMapNode, atX: middleX + xOffset, middleY: middleY, wallTileSize: wallTileSize, moldingTileSize: moldingTileSize, floorTileSize: floorTileSize)
            
            // 왼쪽 열
            if i != 0 { // 중앙 열을 중복으로 처리하지 않기 위해
                addTiles(to: tileMapNode, atX: middleX - xOffset, middleY: middleY, wallTileSize: wallTileSize, moldingTileSize: moldingTileSize, floorTileSize: floorTileSize)
            }
        }
        
        addChild(tileMapNode)  // 타일맵 노드를 장면에 추가
    }
    
    func addTiles(to tileMapNode: SKNode, atX xPosition: CGFloat, middleY: CGFloat, wallTileSize: CGSize, moldingTileSize: CGSize, floorTileSize: CGSize) {
        // Wall Tile 배치 (molding 위)
        var currentY = middleY + moldingTileSize.height / 2
        
        while currentY < frame.maxY {
            let wallTileNode = SKSpriteNode(texture: wallTileTexture)
            currentY += wallTileSize.height / 2
            wallTileNode.position = CGPoint(x: xPosition, y: currentY)
            tileMapNode.addChild(wallTileNode)
            currentY += wallTileSize.height / 2
        }
        
        // Floor Tile 배치 (molding 아래)
        currentY = middleY - moldingTileSize.height / 2
        while currentY > frame.minY {
            let floorTileNode = SKSpriteNode(texture: floorTileTexture)
            currentY -= floorTileSize.height / 2
            floorTileNode.position = CGPoint(x: xPosition, y: currentY)
            tileMapNode.addChild(floorTileNode)
            currentY -= floorTileSize.height / 2
        }
    }
    
    func addWindowToTileMap() {
        let windowTileNode = SKSpriteNode(texture: windowTileTexture)
        
        // 크기 조절: 원하는 크기로 설정
        let desiredWidth: CGFloat = frame.width / 3.5
        let desiredHeight: CGFloat = frame.height / 3.5
        let desiredSize = CGSize(width: desiredWidth, height: desiredHeight)
        
        // 창문 타일의 크기를 조절합니다.
        // 비율을 유지하며 크기 조정
        let aspectRatio = windowTileTexture.size().width / windowTileTexture.size().height
        if desiredSize.width / desiredSize.height > aspectRatio {
            windowTileNode.size = CGSize(width: desiredSize.height * aspectRatio, height: desiredSize.height)
        } else {
            windowTileNode.size = CGSize(width: desiredSize.width, height: desiredSize.width / aspectRatio)
        }
        
        // 위치 설정: 중앙에서 약간 이동
        windowTileNode.position = CGPoint(x: frame.midX - frame.midX/2, y: frame.midY + frame.midY/2)
        
        addChild(windowTileNode)
    }
    
    func catMove() {
        var positionX: CGFloat = 0.0
        var positionY: CGFloat = 0.0
//        var attempts = 0
//        let maxAttempts = 10

        // Define screen boundaries considering catSprite size
        let minX = catSprite.size.width / 2
        let maxX = size.width - catSprite.size.width / 2
        let minY = catSprite.size.height / 2
        let maxY = size.height / 2 - catSprite.size.height / 2
        
        // 충돌하지 않는 랜덤 위치 찾기
        repeat {
            positionX = CGFloat.random(in: minX...maxX)
            positionY = CGFloat.random(in: minY...maxY)
        } while (checkCollisionAt(position: CGPoint(x: positionX, y: positionY)) || checkZPositionAt(position: CGPoint(x: positionX, y: positionY)))

        // If still colliding after max attempts, try nearby positions
//        while checkCollisionAt(position: CGPoint(x: positionX, y: positionY)) || checkZPositionAt(position: CGPoint(x: positionX, y: positionY)) {
//            positionX += CGFloat.random(in: -20...20)
//            positionY += CGFloat.random(in: -20...20)
//            
//            // Ensure new positions are within bounds
//            if positionX < minX { positionX = minX }
//            if positionX > maxX { positionX = maxX }
//            if positionY < minY { positionY = minY }
//            if positionY > maxY { positionY = maxY }
//        }
        
        let catMove = SKAction.move(to: CGPoint(x: positionX, y: positionY), duration: TimeInterval(CGFloat(4.0)))

        // 방향에 따라 고양이 스프라이트 반전
        if positionX < catSprite.position.x {
            catSprite.xScale = -1 // 왼쪽으로 이동할 때 반전
        } else {
            catSprite.xScale = 1 // 오른쪽으로 이동할 때 원래 방향
        }

        // 고양이 스프라이트가 항상 다른 물체들보다 위에 있도록 설정
        catSprite.zPosition = 5
        
        catSprite.run(catMove)
    }
    
    // 충돌 체크 함수
    func checkCollisionAt(position: CGPoint) -> Bool {
        let testNode = SKSpriteNode()
        testNode.position = position
        testNode.size = catSprite.size
        testNode.physicsBody = SKPhysicsBody(rectangleOf: testNode.size)
        testNode.physicsBody?.categoryBitMask = PhysicsCategory.cat
        testNode.physicsBody?.collisionBitMask = PhysicsCategory.furniture
        testNode.physicsBody?.contactTestBitMask = PhysicsCategory.furniture
        testNode.physicsBody?.isDynamic = true
        testNode.physicsBody?.affectedByGravity = false
        
        for node in children {
            if let body = node.physicsBody, body.categoryBitMask == PhysicsCategory.furniture {
                if testNode.frame.intersects(node.frame) {
                    return true
                }
            }
        }
        return false
    }

    // zPosition 체크 함수
    func checkZPositionAt(position: CGPoint) -> Bool {
        for node in children {
            if node.contains(position) && node.zPosition >= catSprite.zPosition {
                return true
            }
        }
        return false
    }
    
    func talkMove() {
        // 말풍선 이동 설정
        let talkMove = SKAction.move(to: CGPoint(x: catSprite.position.x, y: catSprite.position.y), duration: TimeInterval(0.01))
        bubbleSprite.run(talkMove)
    }
    
    func moveTime(from currentTime: TimeInterval) {
        // 고양이 이동 및 애니메이션 조절
        if animationTime > 300 && 300 < saveTime && saveTime < 600 {
            let number = Int.random(in: 0...2)
            switch number {
            case 0: startCatIdleAnimation()
            case 1: startCatLickingAnimation()
            case 2: startCatSittingAnimation()
            default:
                break
            }
            animationTime = 0
        }
        
        animationTime += 1
        saveTime += 1
        
        if saveTime > 600 {
            catMove()
            startCatWalkingAnimation()
            saveTime = 0
        }
    }
    
    func dirtySprite(position: CGPoint, imageName: String, index: Int) {
        let dirtySprite = SKSpriteNode(imageNamed: imageName)
        dirtySprite.name = "dirtySprite\(index)"
        dirtySprite.size = CGSize(width: 50, height: 50)
        dirtySprite.position = position
        dirtySprite.zPosition = 2.5
        addChild(dirtySprite)
    }
    
    func dirtyUI() {
        if self.dirtySpriteData.isEmpty || self.dirtyCount != self.dirtySpriteData.count {
            // 청결도에 따라 dirtySprite 수 결정
            let numberOfSprites = max(0, min(self.dirtyCount, 10))
            
            for index in 0 ..< numberOfSprites {
                var position: CGPoint = randomPosition()
                var attempts = 0
                let maxAttempts = 10
                
                // 충돌하지 않는 랜덤 위치 찾기
                repeat {
                    position = randomPosition()
                    attempts += 1
                } while checkCollisionAt(position: position) && attempts < maxAttempts
                
                let imageName = dirtySpriteList[Int.random(in: 0 ..< dirtySpriteList.count)]
                
                self.dirtySpriteData["dirtySprite\(index)"] = ["imageName": imageName, "position": [position.x, position.y]]
                dirtySprite(position: position, imageName: imageName, index: index)
            }
            
            // 데이터 저장
            DatabaseUtils.shared.updateRoomDirty(dirty: self.dirtyCount, spriteList: self.dirtySpriteData, index: -1) { _, _ in }
        } else {
            for (key, data) in self.dirtySpriteData {
                if let index = Int(key.replacingOccurrences(of: "dirtySprite", with: "")) {
                    let position = data["position"] as! [CGFloat]
                    let imageName = data["imageName"] as! String
                    dirtySprite(position: CGPoint(x: position[0], y: position[1]), imageName: imageName, index: index)
                }
            }
        }
    }
    
    func roomUI() {
        var targetSize = CGSize(width: 80, height: 80)
        
        // 배치한 가구가 있는 경우, 정해진 위치에 가구 설정
        for i in 0 ..< (roomSpriteList["window"]?.count ?? 1) {
            if roomSpriteList["window"]?[i].isPlaced == true {
                let windowSprite_1 = SKSpriteNode(imageNamed: roomSpriteList["window"]?[i].imageName ?? "window_01_01")
                targetSize = CGSize(width: 60, height: 60)
                windowSprite_1.adjustAspectFill(to: targetSize)
                windowSprite_1.position = .relativePosition(x: 0.8, y: 0.8, in: frame)
                windowSprite_1.zPosition = -5
                addChild(windowSprite_1)
                
                let windowSprite_2 = SKSpriteNode(imageNamed: roomSpriteList["window"]?[i].imageName ?? "window_01_01")
                targetSize = CGSize(width: 60, height: 60)
                windowSprite_2.adjustAspectFill(to: targetSize)
                windowSprite_2.position = .relativePosition(x: 0.2, y: 0.8, in: frame)
                windowSprite_2.zPosition = -5
                addChild(windowSprite_2)
            }
        }
        
        for i in 0 ..< (roomSpriteList["rug"]?.count ?? 1) {
            if roomSpriteList["rug"]?[i].isPlaced == true {
                let rugSprite = SKSpriteNode(imageNamed: roomSpriteList["rug"]?[i].imageName ?? "rug_01_01")
                targetSize = CGSize(width: 60, height: 60)
                rugSprite.adjustAspectFill(to: targetSize)
                rugSprite.position = .relativePosition(x: 0.8, y: 0.26, in: frame)
                rugSprite.zPosition = 0
                addChild(rugSprite)
            }
        }
        
        for i in 0 ..< (roomSpriteList["lightning"]?.count ?? 1) {
            if roomSpriteList["lightning"]?[i].isPlaced == true {
                let lightningSprite_1 = SKSpriteNode(imageNamed: roomSpriteList["lightning"]?[i].imageName ?? "lightning_01_01")
                targetSize = CGSize(width: 25, height: 25)
                lightningSprite_1.adjustAspectFill(to: targetSize)
                lightningSprite_1.zPosition = 3
                lightningSprite_1.physicsBody = SKPhysicsBody(rectangleOf: lightningSprite_1.size)
                lightningSprite_1.physicsBody?.categoryBitMask = PhysicsCategory.furniture
                lightningSprite_1.physicsBody?.collisionBitMask = PhysicsCategory.cat
                lightningSprite_1.physicsBody?.contactTestBitMask = PhysicsCategory.cat
                lightningSprite_1.physicsBody?.isDynamic = false
                
                let lightningSprite_2 = SKSpriteNode(imageNamed: roomSpriteList["lightning"]?[i].imageName ?? "lightning_01_01")
                targetSize = CGSize(width: 25, height: 25)
                lightningSprite_2.adjustAspectFill(to: targetSize)
                lightningSprite_2.zPosition = 3
                lightningSprite_2.physicsBody = SKPhysicsBody(rectangleOf: lightningSprite_2.size)
                lightningSprite_2.physicsBody?.categoryBitMask = PhysicsCategory.furniture
                lightningSprite_2.physicsBody?.collisionBitMask = PhysicsCategory.cat
                lightningSprite_2.physicsBody?.contactTestBitMask = PhysicsCategory.cat
                lightningSprite_2.physicsBody?.isDynamic = false
                
                switch roomSpriteList["lightning"]?[i].imageName.split(separator: "_")[1] {
                case "01":
                    lightningSprite_1.position = .relativePosition(x: 0.40, y: 0.75, in: frame)
                    lightningSprite_2.position = .relativePosition(x: 0.6, y: 0.75, in: frame)
                    addChild(lightningSprite_2)
                case "02":
                    lightningSprite_1.position = .relativePosition(x: 0.4, y: 0.9, in: frame)
                    lightningSprite_2.position = .relativePosition(x: 0.56, y: 0.9, in: frame)
                    addChild(lightningSprite_2)
                case "03":
                    lightningSprite_1.position = .relativePosition(x: 0.6, y: 0.5, in: frame)
                case "04":
                    lightningSprite_1.position = .relativePosition(x: 0.5, y: 0.9, in: frame)
                default:
                    break
                }
                
                addChild(lightningSprite_1)
            }
        }
        
        for i in 0 ..< (roomSpriteList["plant"]?.count ?? 1) {
            if roomSpriteList["plant"]?[i].isPlaced == true {
                let plantSprite = SKSpriteNode(imageNamed: roomSpriteList["plant"]?[i].imageName ?? "plant_01_01")
                targetSize = CGSize(width: 40, height: 40)
                plantSprite.adjustAspectFill(to: targetSize)
                plantSprite.position = .relativePosition(x: 0.2, y: 0.5, in: frame)
                plantSprite.zPosition = 2.5
                addChild(plantSprite)
            }
        }
        
        for i in 0 ..< (roomSpriteList["sofa"]?.count ?? 1) {
            if roomSpriteList["sofa"]?[i].isPlaced == true {
                let sofaSprite = SKSpriteNode(imageNamed: roomSpriteList["sofa"]?[i].imageName ?? "sofa_01_01")
                targetSize = CGSize(width: 70, height: 60)
                sofaSprite.adjustAspectFill(to: targetSize)
                sofaSprite.position = .relativePosition(x: 0.4, y: 0.5, in: frame)
                sofaSprite.zPosition = 3
                
//                sofaSprite.physicsBody = SKPhysicsBody(rectangleOf: sofaSprite.size)
//                sofaSprite.physicsBody?.categoryBitMask = PhysicsCategory.furniture
//                sofaSprite.physicsBody?.collisionBitMask = PhysicsCategory.cat
//                sofaSprite.physicsBody?.contactTestBitMask = PhysicsCategory.cat
//                sofaSprite.physicsBody?.isDynamic = false
                addChild(sofaSprite)
            }
        }
        
        for i in 0 ..< (roomSpriteList["table"]?.count ?? 1) {
            if roomSpriteList["table"]?[i].isPlaced == true {
                let tableSprite = SKSpriteNode(imageNamed: roomSpriteList["table"]?[i].imageName ?? "table_01_01")
                targetSize = CGSize(width: 50, height: 50)
                tableSprite.adjustAspectFill(to: targetSize)
                tableSprite.position = .relativePosition(x: 0.2, y: 0.2, in: frame)
                tableSprite.zPosition = 3
                
                let upperBodySize = CGSize(width: tableSprite.size.width, height: tableSprite.size.height / 1.5)
                let upperBodyOffset = CGPoint(x: 0, y: tableSprite.size.height / 6)
                
                tableSprite.physicsBody = SKPhysicsBody(rectangleOf: upperBodySize, center: upperBodyOffset)
                tableSprite.physicsBody?.categoryBitMask = PhysicsCategory.furniture
                tableSprite.physicsBody?.collisionBitMask = PhysicsCategory.cat
                tableSprite.physicsBody?.contactTestBitMask = PhysicsCategory.cat
                tableSprite.physicsBody?.isDynamic = false
                addChild(tableSprite)
            }
        }
        
        for i in 0 ..< (roomSpriteList["chair"]?.count ?? 1) {
            if roomSpriteList["chair"]?[i].isPlaced == true {
                let chairSprite = SKSpriteNode(imageNamed: roomSpriteList["chair"]?[i].imageName ?? "chair_01_01")
                targetSize = CGSize(width: 30, height: 30)
                chairSprite.adjustAspectFill(to: targetSize)
                chairSprite.position = .relativePosition(x: 0.35, y: 0.2, in: frame)
                chairSprite.zPosition = 3
                addChild(chairSprite)
            }
        }
        
        for i in 0 ..< (roomSpriteList["catTower"]?.count ?? 1) {
            if roomSpriteList["catTower"]?[i].isPlaced == true {
                let catTowerSprite = SKSpriteNode(imageNamed: roomSpriteList["catTower"]?[i].imageName ?? "catTower_01_01")
                targetSize = CGSize(width: 70, height: 70)
                catTowerSprite.adjustAspectFill(to: targetSize)
                catTowerSprite.position = .relativePosition(x: 0.85, y: 0.5, in: frame)
                catTowerSprite.zPosition = 3
                
                catTowerSprite.physicsBody = SKPhysicsBody(rectangleOf: catTowerSprite.size)
                catTowerSprite.physicsBody?.categoryBitMask = PhysicsCategory.furniture
                catTowerSprite.physicsBody?.collisionBitMask = PhysicsCategory.cat
                catTowerSprite.physicsBody?.contactTestBitMask = PhysicsCategory.cat
                catTowerSprite.physicsBody?.isDynamic = false
                addChild(catTowerSprite)
            }
        }
    }
    
    func emitterUI() {
        // 하트 애니메이션 설정
        let emitterNode = SKEmitterNode()

        // EmitterNode의 위치를 catSprite 근처로 설정
        emitterNode.position = CGPoint(x: catSprite.position.x, y: catSprite.position.y + catSprite.size.height)
        emitterNode.zPosition = 10 // 높은 zPosition 설정
        
        // EmitterNode의 파티클 설정
        emitterNode.particleTexture = SKTexture(imageNamed: "heart")
        emitterNode.particleBirthRate = 5
        emitterNode.particleLifetime = 1.0
        emitterNode.particlePositionRange = CGVector(dx: 50, dy: 50)
        emitterNode.particleSpeed = 50
        emitterNode.particleSpeedRange = 20
        emitterNode.emissionAngleRange = .pi / 4
        emitterNode.particleAlpha = 1.0
        emitterNode.particleAlphaRange = 0.5
        emitterNode.particleAlphaSpeed = -0.5
        emitterNode.particleScale = 0.005 // 크기 조절
        emitterNode.particleScaleRange = 0.01 // 크기 범위 조절
        emitterNode.particleScaleSpeed = -0.01
        emitterNode.particleColor = .red

        // emitterNode를 장면에 추가
        addChild(emitterNode)

        // 0.5초 후에 emitterNode 제거
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            emitterNode.particleBirthRate = 0
            emitterNode.removeFromParent()
        }
    }

    func spriteUI() {
        // 배경, 고양이, 말풍선 위치 및 크기 설정
        catSprite = SKSpriteNode(imageNamed: DatabaseUtils.shared.sittingCatImage[0] as! String)
        catSprite.name = "catSprite"
        
        catSprite.adjustAspectFill(to: catSize)
        
        catSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        catSprite.zPosition = 4 // catSprite의 zPosition 설정
        let lowerBodySize = CGSize(width: catSprite.size.width / 1.5, height: catSprite.size.height / 3)
        let lowerBodyOffset = CGPoint(x: 0, y: -catSprite.size.height / 4)
        
        catSprite.physicsBody = SKPhysicsBody(rectangleOf: lowerBodySize, center: lowerBodyOffset)
        catSprite.physicsBody?.categoryBitMask = PhysicsCategory.cat
        catSprite.physicsBody?.collisionBitMask = PhysicsCategory.furniture
        catSprite.physicsBody?.contactTestBitMask = PhysicsCategory.furniture
        catSprite.physicsBody?.isDynamic = true
        catSprite.physicsBody?.affectedByGravity = false
        catSprite.physicsBody?.allowsRotation = false // 회전 방지
        addChild(catSprite)
        
        bubbleSprite.size = CGSize(width: 0, height: 0)
        bubbleSprite.position = CGPoint(x: catSprite.position.x, y: catSprite.position.y)
        bubbleSprite.zPosition = 10 // 가장 위에 오도록 설정
        addChild(bubbleSprite)
    }
    
    func startCatWalkingAnimation() {
        // 고양이 걷는 애니메이션 프레임 배열 생성
        var walkFrames: [SKTexture] = []
        for imageName in DatabaseUtils.shared.walkingCatImage {
            let frame = SKTexture(imageNamed: imageName as! String)
            walkFrames.append(frame)
        }
        
        // 애니메이션 액션 생성
        let walkAnimation = SKAction.animate(with: walkFrames, timePerFrame: 0.1)
        let repeatWalkAnimation = SKAction.repeatForever(walkAnimation)
        
        // 고양이 스프라이트에 애니메이션 실행
        catSprite.run(repeatWalkAnimation)
    }
    
    func startCatIdleAnimation() {
        // 고양이 기본 애니메이션 프레임 배열 생성
        var idleFrames: [SKTexture] = []
        for imageName in DatabaseUtils.shared.idleCatImage {
            let texture = SKTexture(imageNamed: imageName as! String)
            idleFrames.append(texture)
        }
        
        let idleAnimation = SKAction.animate(with: idleFrames, timePerFrame: 0.2)
        let repeatIdleAnimation = SKAction.repeatForever(idleAnimation)
        catSprite.run(repeatIdleAnimation)
    }
    
    func startCatLickingAnimation() {
        // 고양이 핥기 애니메이션 프레임 배열 생성
        var lickingFrames: [SKTexture] = []
        for imageName in DatabaseUtils.shared.lickingCatImage {
            let texture = SKTexture(imageNamed: imageName as! String)
            lickingFrames.append(texture)
        }
        
        let lickingAnimation = SKAction.animate(with: lickingFrames, timePerFrame: 0.1)
        let repeatLickingAnimation = SKAction.repeatForever(lickingAnimation)
        catSprite.run(repeatLickingAnimation)
    }
    
    func startCatSittingAnimation() {
        // 고양이 앉기 애니메이션 프레임 배열 생성
        var sittingFrames: [SKTexture] = []
        for imageName in DatabaseUtils.shared.sittingCatImage {
            let texture = SKTexture(imageNamed: imageName as! String)
            sittingFrames.append(texture)
        }
        
        let sittingAnimation = SKAction.animate(with: sittingFrames, timePerFrame: 0.1)
        let repeatSittingAnimation = SKAction.repeatForever(sittingAnimation)
        catSprite.run(repeatSittingAnimation)
    }
}

extension GameScene {
    func randomPosition() -> CGPoint {
        let padding: CGFloat = 20.0  // 경계선에서 일정 거리 떨어진 위치를 위한 패딩값 설정
        let xPosition = CGFloat.random(in: padding...(size.width - padding))
        let yPosition = CGFloat.random(in: padding...(size.height / 2 - padding))
        return CGPoint(x: xPosition, y: yPosition)
    }
}

protocol GameSceneDelegate: AnyObject {
    func updatePoints(_ points: Int)
    func showToast(message: String)
    func showBubbleSprite()
}

extension GameScene {
    func showBubbleSprite() {
        bubbleSprite.removeFromParent()
        
        bubbleSprite = SKSpriteNode(imageNamed: bubbleSpriteList[Int.random(in: 0...bubbleSpriteList.count-1)])
        bubbleSprite.size = CGSize(width: 100, height: 100)
        bubbleSprite.position = CGPoint(x: catSprite.position.x, y: catSprite.position.y)
        bubbleSprite.zPosition = 10
        addChild(bubbleSprite)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
            self.bubbleSprite.removeFromParent()
        }
    }
}

extension SKSpriteNode {
    func adjustAspectFill(to targetSize: CGSize) {
        let originalSize = self.size
        
        // 비율 계산
        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
        let scaleFactor = max(widthRatio, heightRatio) // 비율이 큰 쪽으로 맞추기
        
        // 새로운 크기
        let newSize = CGSize(width: originalSize.width * scaleFactor, height: originalSize.height * scaleFactor)
        
        // 새로운 크기로 설정
        self.size = newSize
        
        // 중앙에 위치하도록 설정
        self.position = CGPoint(x: frame.midX, y: frame.midY)
    }
    
    func adjustAspectFit(to targetSize: CGSize) {
        let originalSize = self.size
        
        // 비율 계산
        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
        let scaleFactor = min(widthRatio, heightRatio) // 비율이 작은 쪽으로 맞추기
        
        // 새로운 크기
        let newSize = CGSize(width: originalSize.width * scaleFactor, height: originalSize.height * scaleFactor)
        
        // 새로운 크기로 설정
        self.size = newSize
        
        // 중앙에 위치하도록 설정
        self.position = CGPoint(x: frame.midX, y: frame.midY)
    }
    
    func scaleToFill(to targetSize: CGSize) {
        // targetSize에 맞추어 크기 조절
        self.size = targetSize
        
        // 중앙에 위치하도록 설정
        self.position = CGPoint(x: frame.midX, y: frame.midY)
    }
}

extension CGPoint {
    static func relativePosition(x: CGFloat, y: CGFloat, in frame: CGRect) -> CGPoint {
        return CGPoint(x: frame.width * x, y: frame.height * y)
    }
}

extension GameScene {
    func makeBubbleSprite(with text: String) {
        bubbleSprite.removeFromParent()
        
        // Create the bubble sprite
        bubbleSprite = SKSpriteNode(imageNamed: "bubble")
        bubbleSprite.zPosition = 10
        
        // Define the maximum number of characters per line
        let maxCharactersPerLine = 15
        var currentIndex = 0
        var lines: [String] = []
        
        // Split text into lines
        while currentIndex < text.count {
            let endIndex = min(currentIndex + maxCharactersPerLine, text.count)
            let line = String(text[text.index(text.startIndex, offsetBy: currentIndex)..<text.index(text.startIndex, offsetBy: endIndex)])
            lines.append(line)
            currentIndex += maxCharactersPerLine
        }
        
        let lineHeight: CGFloat = 12
        let totalHeight = lineHeight * CGFloat(lines.count)
        
        let bubbleHeight = totalHeight * 9
        let bubbleWidth: CGFloat = 180 // Fixed width for bubble
        bubbleSprite.scaleToFill(to: CGSize(width: bubbleWidth, height: bubbleHeight))
        bubbleSprite.position = CGPoint(x: catSprite.position.x, y: catSprite.position.y + catSprite.size.height / 2 + bubbleHeight / 2 + totalHeight * 4)
        
        // Add labels to the bubble
        for (index, line) in lines.enumerated() {
            let labelNode = SKLabelNode(text: line)
            labelNode.fontName = "Arial"
            labelNode.fontSize = 11
            labelNode.fontColor = .black
            labelNode.horizontalAlignmentMode = .center
            labelNode.verticalAlignmentMode = .center
            labelNode.position = CGPoint(x: 0, y: bubbleHeight / 2 - CGFloat(index) * lineHeight - lineHeight / 2 - 4)
            labelNode.zPosition = 11
            bubbleSprite.addChild(labelNode)
        }
        
        // Add the bubble to the scene
        addChild(bubbleSprite)
        
        // Remove the bubble after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
            self.bubbleSprite.removeFromParent()
        }
    }
}
