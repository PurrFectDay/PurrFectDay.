//
//  firebaseUtils.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/05/25.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase


class DatabaseUtils {
    private var handle: AuthStateDidChangeListenerHandle?
    private var ref: DatabaseReference!
    private var userRef: DatabaseReference!
    private var shopRef: DatabaseReference!
    
    internal var user: User? = Auth.auth().currentUser {
        didSet {
            self.email = self.user?.email
        }
    }
    internal var email: String?
    
    private var point: Int!
    // 한국 표준시(KST) 시간대를 설정
    let koreaTimeZone = TimeZone(identifier: "Asia/Seoul")!
    private var s_date: String?
    private var d_date: Date?
    var eventsCountDict: [String: Int] = [:]

    internal var placedList: [String: String] = [:]
    internal var shopList: [String: [Item]] = [:] {
        didSet {
            for (category, items) in shopList {
                shopList[category] = items.sorted { $0.imageName < $1.imageName }
                
                for i in 0 ..< items.count {
                    if items[i].isPlaced {
                        placedList[category] = items[i].imageName
                    }
                }
            }
        }
    }
    
    var catNum: String = "01" {
        didSet {
            if Int(catNum)! < 1 || Int(catNum)! > 12 {
                catNum = "01"
            }
            
            // 설정한 고양이로 데이터 업데이트
            self.walkingCatImage.removeAll()
            self.idleCatImage.removeAll()
            self.sittingCatImage.removeAll()
            self.lickingCatImage.removeAll()
            
            for i in 1 ... 8 {
                let index = String(format: "%02d", i)
                self.walkingCatImage.append("cat\(String(describing: self.catNum))_walking_\(index)")
            }
            for i in 1 ... 4 {
                let index = String(format: "%02d", i)
                self.idleCatImage.append("cat\(String(describing: self.catNum))_idle_\(index)")
                self.sittingCatImage.append("cat\(String(describing: self.catNum))_sitting_\(index)")
            }
            for i in 1 ... 15 {
                let index = String(format: "%02d", i)
                lickingCatImage.append("cat\(String(describing: self.catNum))_licking_\(index)")
            }
        }
    }
    var walkingCatImage: [Any] = []
    var idleCatImage: [Any] = []
    var lickingCatImage: [Any] = []
    var sittingCatImage: [Any] = []
    
    internal var dirtyCount: Int?
    internal var dirtySpriteData: [String: [String: Any]] = [:]
    
    var goalListArray: [[Any]] = []
    var goalDictionary: [Int: [String: Any]] = [:] {
        didSet {
//            print("didSet goalDictionary: \(self.goalDictionary)")
            
            let sortedKeys = self.goalDictionary.keys.sorted { $0 < $1 }
            self.goalListArray.removeAll()
            for key in sortedKeys {
                if let goal = self.goalDictionary[key] {
                    self.goalListArray.append([key, goal])
                }
            }
        }
    }
    var todoListArray: [[[Any]]] = [[]] {
        didSet {
            // 데이터가 업데이트되었을 때 실행할 작업을 수행
//            print("didSet todoListArray: \(self.todoListArray)")
        }
    }
    private var isTodoCheck = false
    
    var followList: [Friend] = []
    var followerList: [Friend] = []
    var f4fList: [Friend] = []
    var friendRoom: FriendRoom?
    
    internal static let shared = DatabaseUtils()
    
    init() {
        observeAuthState()
    }
    
    private func observeAuthState() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            if let user = user {
                // 사용자가 로그인한 경우
                // 사용자 정보 갱신
                self?.user = user
                self?.initializeData(for: user) { }
            } else {
                // 사용자가 로그아웃한 경우
                // 사용자 정보 초기화 또는 필요한 작업 수행
                self?.user = nil
            }
        }
    }
    
    var initializationCompletion: (() -> Void)?
    
    // 날짜 형식을 위한 DateFormatter 설정
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd" // 날짜 형식에 맞게 수정
        return formatter
    }()

    func initializeData(for user: User?, completion: @escaping () -> Void) {
        self.user = user
        self.initializationCompletion = completion

        guard let user = user else {
            // If user is nil, call the completion immediately
            completion()
            return
        }
        
        self.ref = Database.database().reference()
        self.userRef = Database.database().reference().child("users").child(user.uid)
        self.shopRef = Database.database().reference().child("shop")
        self.d_date = Date()
        self.s_date = self.dateFormatter(date: self.d_date!)
        
        // Call all the initialization methods
        self.getPoint { data in
            self.point = data
            self.checkInitializationCompletion()
        }
        
        self.getGoals() { goal in
            self.goalDictionary = goal
            self.getTodoByDate(date: self.s_date!) { todo in
                self.todoListArray = todo
                self.checkInitializationCompletion()
            }
        }
        
        self.getMainCat() { num in
            self.catNum = num!
            self.checkInitializationCompletion()
        }
        
        self.getTamedCat() { data in
            CatInfo.catTamedList = data
            self.checkInitializationCompletion()
        }
        
        self.getShop() { data in
            self.shopList = data!
            self.checkInitializationCompletion()
        }
        
        self.setRoomDirty() { degreeData, spriteData in
            self.dirtyCount = degreeData
            self.dirtySpriteData = spriteData
            self.checkInitializationCompletion()
        }
        
        self.getFollow(completion: { data in
            self.followList = data
            self.checkInitializationCompletion()
        })
        
        self.getFollower(completion: { data in
            self.followerList = data
            self.checkInitializationCompletion()
        })
        
        self.getF4F(completion: { data in
            self.f4fList = data
            self.checkInitializationCompletion()
        })
        
        completion()
    }
    
    private func checkInitializationCompletion() {
        if self.point != nil &&
            !self.goalDictionary.isEmpty &&
            !self.todoListArray.isEmpty &&
            self.catNum != "" &&
            !CatInfo.catTamedList.isEmpty &&
            !self.shopList.isEmpty &&
            self.dirtyCount != nil &&
            !self.followList.isEmpty &&
            !self.followerList.isEmpty &&
            !self.f4fList.isEmpty
        {
            self.initializationCompletion?()
        }
    }
    
    // MARK: 회원가입
    func setUserData(completion: @escaping (Bool) -> Void) {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let date = self.dateFormatter(date: yesterday!)
        let email = self.user!.email! as String
        let uid = self.user!.uid
        
        let split = email.split(separator: "@")
        let id = split[0]
        let domain = split[1].split(separator: ".")[0]
        
        print("email/domain/\(domain)/\(id)")
        self.ref.child("email/domain/\(domain)/\(id)").setValue(uid)
        
        self.ref.child("email/domain/\(domain)/test").setValue("uid")
        
        self.userRef.setValue([
            "email": email,
            "catInfo": ["mainCat": "01", "tamedCat": ["01": ["name": ""]]],
            "inventory": ["wall": ["01": ["01": "wall_01_01"]], "floor": ["01": ["01": "floor_01_01"]],
                          "molding": ["01": ["01": "molding_01_01"]], "placed": ["wall": "wall_01_01", "floor": "floor_01_01", "molding": "molding_01_01"]],
            "point": 0,
            "dirty": ["\(date)": 0, "total": 0]
            
        ]) { (error, ref) in
            if let error = error { // 오류 발생
                NSLog("Error saving email data: \(error.localizedDescription)")
                completion(false)
            } else { // 오류 없음
                NSLog("Email Data saved successfully")
                completion(true)
            }
        }
    }
    
    func initUserData(completion: @escaping () -> Void) {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let date = self.dateFormatter(date: yesterday!)
        
        self.userRef.observeSingleEvent(of: .value, with: { (snapshot) in
            if !snapshot.exists() { // 데이터가 존재하지 않는 경우 기본 계정 정보 db에 저장
                self.userRef.setValue([
                    "email": self.email! as String,
                    "catInfo": ["mainCat": "01", "tamedCat": ["01": ["name": ""]]],
                    "inventory": ["wall": ["01": ["01": "wall_01_01"]], "floor": ["01": ["01": "floor_01_01"]],
                                  "molding": ["01": ["01": "molding_01_01"]], "placed": ["wall": "wall_01_01", "floor": "floor_01_01", "molding": "molding_01_01"]],
                    "point": 0,
                    "dirty": ["\(date)": 0, "total": 0]
                ])  { (error, ref) in
                    if let error = error { // 오류 발생
                        NSLog("Error saving data on db: \(error.localizedDescription)")
                        
                    } else { // 오류 없음
                        NSLog("Data saved on db successfully")
                    }
                }
                
                self.updateMainCat(index: 1) { data in
                    self.catNum = data!
                    
                    self.updateTamedCat(index: 1, name: "") { data in
                        CatInfo.catTamedList = data
                        
                        BackgroundMusicPlayer.shared.saveInitialVolume(5.0)
                        SoundEffectPlayer.shared.saveInitialVolume(5.0)
                        
                        completion()
                    }
                }
            }
        })
    }
    
    func getEmail(completion: @escaping (String?) -> Void) {
        var data: String?
        
        self.userRef.child("email").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let email = snapshot.value as? String else {
                print("No email available.")
                completion(data)
                return
            }
            data = email
            
            self.email = email
            completion(data)
        }) { (error) in
            print("Error getting email data: \(error.localizedDescription)")
            completion(data)
        }
    }
    
    func searchFriend(domain: String, id: String, completion: @escaping (Bool?) -> Void) {
        self.ref.child("email/domain/\(domain)/\(id)").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let uid = snapshot.value as? String else {
                print("No friend available.")
                completion(false)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var isF4F = false
            var isFollower = false
            var isFollow = false
            
            dispatchGroup.enter()
            self.userRef.child("friend/f4f/\(uid)").observeSingleEvent(of: .value, with: { (snapshot) in
                isF4F = snapshot.exists()
                dispatchGroup.leave()
            }) { (error) in
                print("Error getting friend data: \(error.localizedDescription)")
                dispatchGroup.leave()
            }
            
            dispatchGroup.enter()
            self.userRef.child("friend/follower/\(uid)").observeSingleEvent(of: .value, with: { (snapshot) in
                isFollower = snapshot.exists()
                dispatchGroup.leave()
            }) { (error) in
                print("Error getting friend data: \(error.localizedDescription)")
                dispatchGroup.leave()
            }
            
            dispatchGroup.enter()
            self.userRef.child("friend/follow/\(uid)").observeSingleEvent(of: .value, with: { (snapshot) in
                isFollow = snapshot.exists()
                dispatchGroup.leave()
            }) { (error) in
                print("Error getting friend data: \(error.localizedDescription)")
                dispatchGroup.leave()
            }
            
            dispatchGroup.notify(queue: .main) {
                if isF4F {
                    completion(nil) // 나와 이미 맞팔임
                } else if isFollow {
                    completion(nil)
                } else if isFollower {
                    completion(nil) // 나에게 요청한 상대인데 내가 요청하지 않았으면 true, 이미 요청했으면 nil
                } else {
                    completion(true) // 나에게 요청한 상대가 아님
                }
            }
        }) { (error) in
            print("Error getting friend data: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // 해당 이메일을 가진 유저의 uid 가져옴
    func getFriendUID(domain: String, id: String, completion: @escaping (String?) -> Void) {
        self.ref.child("email/domain/\(domain)/\(id)").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let uid = snapshot.value as? String else {
                print("No friend available.")
                completion(nil)
                return
            }
            
            completion(uid)
        }) { (error) in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // 맞팔 요청 보내기
    func requestFriend(friendEmail: String, completion: @escaping ([Friend]) -> Void) {
        let id = friendEmail.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { friendUserId in
            guard let friendUserId = friendUserId, let currentUserId = self.user?.uid else {
                print("Failed to get friendUserId or currentUserId")
                completion([])
                return
            }
            
            self.userRef.child("friend/follow/\(friendUserId)").setValue("true")
            self.ref.child("users/\(friendUserId)/friend/follower/\(currentUserId)").setValue("false")
            
            self.getFollow(completion: { data in
                self.followList = data
                completion(data)
            })
        })
    }
    
    // 친구 요청 보낸 목록 불러오기
    func getFollow(completion: @escaping ([Friend]) -> Void) {
        var followData: [Friend] = []
        
        self.userRef.child("friend/follow").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let followList = snapshot.children.allObjects as? [DataSnapshot] else {
                print("No friend available.")
                // 친구요청 보낸 사용자 없음
                completion(followData)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            for follow in followList {
                let uid = follow.key
                let state = follow.value as? String
                
                dispatchGroup.enter()
                self.ref.child("users/\(uid)/email").observeSingleEvent(of: .value, with: { (snapshot) in
                    if let email = snapshot.value as? String {
                        self.ref.child("users/\(uid)/catInfo/mainCat").observeSingleEvent(of: .value, with: { (snapshot) in
                            if let catNum = snapshot.value as? String {
                                followData.append(Friend(profileImage: "cat\(catNum)_sitting_01", email: email, state: state ?? "false"))
                            } else {
                                print("Failed to get catInfo for user: \(uid)")
                            }
                            dispatchGroup.leave()
                        }) { (error) in
                            print("Error getting catInfo: \(error.localizedDescription)")
                            dispatchGroup.leave()
                        }
                    } else {
                        print("Failed to get email for user: \(uid)")
                        dispatchGroup.leave()
                    }
                }) { (error) in
                    print("Error getting email: \(error.localizedDescription)")
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(followData)
            }
        }) { (error) in
            print("Error getting friend data: \(error.localizedDescription)")
            completion(followData)
        }
    }
    
    func getFollower(completion: @escaping ([Friend]) -> Void) {
        var followerData: [Friend] = []
        
        self.userRef.child("friend/follower").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let followerList = snapshot.children.allObjects as? [DataSnapshot] else {
                print("No friend available.")
                // 친구요청 보낸 사용자 없음
                completion(followerData)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            for follower in followerList {
                let uid = follower.key
                let state = follower.value as! String
                
                dispatchGroup.enter()
                self.ref.child("users/\(uid)/email").observeSingleEvent(of: .value, with: { (snapshot) in
                    if let email = snapshot.value as? String {
                        self.ref.child("users/\(uid)/catInfo/mainCat").observeSingleEvent(of: .value, with: { (snapshot) in
                            if let catNum = snapshot.value as? String {
                                followerData.append(Friend(profileImage: "cat\(catNum)_sitting_01", email: email, state: state))
                            } else {
                                print("Failed to get catInfo for user: \(uid)")
                            }
                            dispatchGroup.leave()
                        }) { (error) in
                            print("Error getting catInfo: \(error.localizedDescription)")
                            dispatchGroup.leave()
                        }
                    } else {
                        print("Failed to get email for user: \(uid)")
                        dispatchGroup.leave()
                    }
                }) { (error) in
                    print("Error getting email: \(error.localizedDescription)")
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(followerData)
            }
        }) { (error) in
            print("Error getting friend data: \(error.localizedDescription)")
            completion(followerData)
        }
    }
    
    func getF4F(completion: @escaping ([Friend]) -> Void) {
        var f4fData: [Friend] = []
        
        self.userRef.child("friend/f4f").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let f4fList = snapshot.children.allObjects as? [DataSnapshot] else {
                print("No friend available.")
                // 친구요청 보낸 사용자 없음
                completion(f4fData)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            for f4f in f4fList {
                let uid = f4f.key
                let state = f4f.value as! String
                
                dispatchGroup.enter()
                self.ref.child("users/\(uid)/email").observeSingleEvent(of: .value, with: { (snapshot) in
                    if let email = snapshot.value as? String {
                        self.ref.child("users/\(uid)/catInfo/mainCat").observeSingleEvent(of: .value, with: { (snapshot) in
                            if let catNum = snapshot.value as? String {
                                f4fData.append(Friend(profileImage: "cat\(catNum)_sitting_01", email: email, state: state))
                            } else {
                                print("Failed to get catInfo for user: \(uid)")
                            }
                            dispatchGroup.leave()
                        }) { (error) in
                            print("Error getting catInfo: \(error.localizedDescription)")
                            dispatchGroup.leave()
                        }
                    } else {
                        print("Failed to get email for user: \(uid)")
                        dispatchGroup.leave()
                    }
                }) { (error) in
                    print("Error getting email: \(error.localizedDescription)")
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(f4fData)
            }
        }) { (error) in
            print("Error getting friend data: \(error.localizedDescription)")
            completion(f4fData)
        }
    }
    
    func cancelFollow(email: String, completion: @escaping ([Friend]?) -> Void) {
        let id = email.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { uid in
            let friendUid = uid!
            let currentUid = self.user!.uid
            
            print(friendUid)
            print(currentUid)
            
            self.userRef.child("friend/follow/\(friendUid)").removeValue()
            self.ref.child("users/\(friendUid)/friend/follower/\(currentUid)").removeValue()
            
            self.getFollow(completion: { data in
                self.followList = data
                completion(data)
            })
        })
    }
    
    func acceptFollow(email: String, completion: @escaping ([Friend], [Friend]) -> Void) {
        let id = email.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { uid in
            let friendUid = uid!
            let currentUid = self.user!.uid
            
            self.userRef.child("friend/follower/\(friendUid)").removeValue()
            self.userRef.child("friend/f4f/\(friendUid)").setValue("true")
            
            self.ref.child("users/\(friendUid)/friend/follow/\(currentUid)").removeValue()
            self.ref.child("users/\(friendUid)/friend/f4f/\(currentUid)").setValue("new")
            
            self.getFollower(completion: { data in
                self.followerList = data
                
                self.getF4F(completion: { data in
                    self.f4fList = data
                    
                    completion(self.followerList, self.f4fList)
                })
            })
        })
    }
    
    func rejectFollow(email: String, completion: @escaping ([Friend]?) -> Void) {
        let id = email.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { uid in
            let friendUid = uid!
            let currentUid = self.user!.uid
            
            self.userRef.child("friend/follower/\(friendUid)").removeValue()
            
            self.ref.child("users/\(friendUid)/friend/follow/\(currentUid)").setValue("false")
            
            self.getFollower(completion: { data in
                self.followerList = data
                completion(data)
            })
        })
    }
    
    func confirmF4F(email: String, completion: @escaping ([Friend]?) -> Void) {
        let id = email.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { uid in
            let friendUid = uid!
            _ = self.user!.uid
            
            self.userRef.child("friend/f4f/\(friendUid)").setValue("true")
            
            self.getF4F(completion: { data in
                self.f4fList = data
                completion(data)
            })
        })
    }
    
    func unfollowF4F(email: String, completion: @escaping ([Friend]?) -> Void) {
        let id = email.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { uid in
            let friendUid = uid!
            let currentUid = self.user!.uid
            
            self.userRef.child("friend/f4f/\(friendUid)").removeValue()
            self.ref.child("users/\(friendUid)/friend/f4f/\(currentUid)").setValue("false")
            
            self.getF4F(completion: { data in
                self.f4fList = data
                completion(data)
            })
        })
    }
    
    func unfollowF4F2(email: String, completion: @escaping ([Friend]?) -> Void) {
        let id = email.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { uid in
            let friendUid = uid!
            _ = self.user!.uid
            
            self.userRef.child("friend/f4f/\(friendUid)").removeValue()
            
            
            self.getF4F(completion: { data in
                self.f4fList = data
                completion(data)
            })
        })
    }
    
    func getF4FRoom(email: String, completion: @escaping (FriendRoom?) -> Void) {
        let id = email.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        var friendRoom = FriendRoom( goalDictionary: [:], placedItems: PlacedItmes(wall: "", floor: "", molding: "", window: "", rug: "", table: "", chair: "", sofa: "", lightning: "", plant: "", catTower: ""))  // FriendRoom 객체 초기화
        let dispatchGroup = DispatchGroup()
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { uid in
            guard let friendUid = uid else {
                completion(nil)
                return
            }
            
            let friendRef = self.ref.child("users/\(friendUid)")
            
            // 방에 배치된 물건들 가져오기
            dispatchGroup.enter()
            friendRef.child("inventory/placed").observeSingleEvent(of: .value, with: { (snapshot) in
                if let placedData = snapshot.value as? [String: String] {
                    for (category, imageName) in placedData {
                        switch category {
                        case "wall":
                            friendRoom.placedItems.wall = imageName
                        case "floor":
                            friendRoom.placedItems.floor = imageName
                        case "molding":
                            friendRoom.placedItems.molding = imageName
                        case "window":
                            friendRoom.placedItems.window = imageName
                        case "rug":
                            friendRoom.placedItems.rug = imageName
                        case "table":
                            friendRoom.placedItems.table = imageName
                        case "chair":
                            friendRoom.placedItems.chair = imageName
                        case "sofa":
                            friendRoom.placedItems.sofa = imageName
                        case "lightning":
                            friendRoom.placedItems.lightning = imageName
                        case "plant":
                            friendRoom.placedItems.plant = imageName
                        case "catTower":
                            friendRoom.placedItems.catTower = imageName
                        default:
                            break
                        }
                    }
                }
                dispatchGroup.leave()
            }) { (error) in
                print("Error getting placed items: \(error.localizedDescription)")
                dispatchGroup.leave()
            }
            
            // 총 쓰레기 개수와 현재 배치된 쓰레기에 대한 정보 가져오기
            dispatchGroup.enter()
            friendRef.child("dirty").observeSingleEvent(of: .value, with: { (snapshot) in
                if let dirtyData = snapshot.value as? [String: Any] {
                    friendRoom.dirtyCount = dirtyData["total"] as? Int ?? 0
                    if let spriteList = dirtyData["sprite"] as? [String: [String: Any]] {
                        friendRoom.dirtySpriteData = spriteList
                    }
                }
                dispatchGroup.leave()
            }) { (error) in
                print("Error getting dirty data: \(error.localizedDescription)")
                dispatchGroup.leave()
            }
            
            dispatchGroup.enter()
            friendRef.child("todoList/goal").observeSingleEvent(of: .value, with: { snapshot in
                var goalData: [Int: [String: Any]] = [:]
                for case let child as DataSnapshot in snapshot.children {
                    if let key = Int(child.key), let data = child.value as? [String: Any] {
                        goalData[key] = data
                    }
                }
                
                friendRoom.goalDictionary = goalData
                
                let sortedKeys = friendRoom.goalDictionary.keys.sorted { $0 < $1 }
                var goalListArray: [[Any]] = []
                for key in sortedKeys {
                    if let goal = friendRoom.goalDictionary[key] {
                        goalListArray.append([key, goal])
                    }
                }
                
                friendRoom.goalListArray = goalListArray
                dispatchGroup.leave()
            }) { error in
                print("Error getting todo data: \(error.localizedDescription)")
                dispatchGroup.leave()
            }
            
            // 날짜가 오늘인 투두 목록 가져오기
            let today = self.dateFormatter(date: Date())
            dispatchGroup.enter()
            friendRef.child("todoList/todo/\(today)").observeSingleEvent(of: .value, with: { (snapshot) in
                var todoData: [[[Any]]] = []
                var goalKeys: [Int] = []
                
                for _ in 0 ..< self.goalDictionary.count {
                    todoData.append([])
                }
                
                for goal in self.goalListArray {
                    goalKeys.append(goal[0] as! Int)
                }
                
                guard let todoArrs = snapshot.children.allObjects as? [DataSnapshot] else {
                    print("Data format is not as expected. Maybe empty.")
                    // 데이터가 없으면 빈 배열 반환
                    friendRoom.todoListArray = []
                    friendRoom.progress = 0
                    dispatchGroup.leave()
                    return
                }
                
                for (_, todoArr) in todoArrs.enumerated() {
                    guard let key = goalKeys.firstIndex(of: Int(todoArr.key)!) else {
                        continue
                    }
                    
                    for child in todoArr.children {
                        guard let todoSnap = child as? DataSnapshot, let todo = todoSnap.value as? [Any] else {
                            continue
                        }
                        todoData[key].append(todo)
                    }
                }
                
                friendRoom.todoListArray = todoData
                
                var progressData = 0
                var todoCount = 0
                var doneCount = 0
                for (_, todoArr) in todoArrs.enumerated() {
                    for child in todoArr.children {
                        guard let todoSnap = child as? DataSnapshot, let todo = todoSnap.value as? [Any] else {
                            continue
                        }
                        todoCount += 1
                        if let isDone = todo[1] as? Bool, isDone {
                            doneCount += 1
                        }
                    }
                }
                
                if todoCount != 0 {
                    progressData = Int(Float(doneCount) / Float(todoCount) * 100)
                } else {
                    progressData = 0
                }
                
                friendRoom.progress = progressData
                
                dispatchGroup.leave()
            }) { (error) in
                print("Error getting todo data: \(error.localizedDescription)")
                dispatchGroup.leave()
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(friendRoom)
            }
        })
    }
    
    func sendBubble(email: String, bubble: String, completion: @escaping () -> Void) {
        let id = email.split(separator: "@")
        let domain = id[1].split(separator: ".")
        
        self.getFriendUID(domain: String(domain[0]), id: String(id[0]), completion: { uid in
            let friendUid = uid!
            let friendRef = self.ref.child("users/\(friendUid)")
            let today = self.dateFormatter(date: Date())
            let myUid = self.user!.uid
            let timeStamp = Int(Date().timeIntervalSince1970)
            friendRef.child("friend/bubble/\(today)/\(myUid)/\(timeStamp)").setValue(bubble)
        })
        
        completion()
    }
    
    func getBubble(completion: @escaping ([String]) -> Void) {
        let today = self.dateFormatter(date: Date())
        var bubbleData: [String] = []
        
        self.userRef.child("friend/bubble/\(today)").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let snap = snapshot.children.allObjects as? [DataSnapshot] else {
                print("no bubbleSnap")
                completion(bubbleData)
                return
            }
            
            
            for bubbleSnap in snap {
                if let bubbleDict = bubbleSnap.value as? [String: String] {
                    // 키를 Int로 변환하여 정렬합니다.
                    let sortedKeys = bubbleDict.keys.compactMap { Int($0) }.sorted()
                    for key in sortedKeys {
                        if let bubble = bubbleDict[String(key)] {
                            bubbleData.append(bubble)
                        }
                    }
                }
            }
            
            completion(bubbleData)
        })
    }
    
    func getMainCat(completion: @escaping (String?) -> Void) {
        var num = "01"
        
        self.userRef.child("catInfo/mainCat").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let catNum = snapshot.value as? String else {
                print("No mainCat available.")
                completion(num)
                return
            }
            
            num = catNum
            
            self.catNum = num
            completion(num)
        }) { (error) in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(num)
        }
    }
    
    func updateMainCat(index: Int, completion: @escaping (String?) -> Void) {
        let num = String(format: "%02d", index)
        self.userRef.child("catInfo/mainCat").setValue(num)
        
        self.catNum = num
        completion(num)
    }
    
    func getTamedCat(completion: @escaping ([String:String]) -> Void) {
        var data: [String:String] = [:]
        
        self.userRef.child("catInfo/tamedCat").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let tamedCat = snapshot.value as? [String: [String:String]] else {
                print("No tamedCat available.")
                completion(data)
                return
            }
            
            for (key, value) in tamedCat {
                data[key] = value["name"]
            }
            
            CatInfo.catTamedList = data
            completion(data)
        }) { (error) in
            print("Error getting cat data: \(error.localizedDescription)")
            completion(data)
        }
    }
    
    func updateTamedCat(index: Int, name: String, completion: @escaping ([String:String]) -> Void) {
        var tamedData: [String:String] = CatInfo.catTamedList
        let catNum = String(format: "%02d", index)
        
        tamedData[String(format: "%02d", index)] = name
        self.userRef.child("catInfo/tamedCat/\(catNum)/name").setValue(name)
        
        CatInfo.catTamedList = tamedData
        completion(tamedData)
    }
    
    func getProgress(completion: @escaping (Int) -> Void) {
        var progressData = 0
        var todoCount = 0
        var doneCount = 0
        
        let today = dateFormatter(date: Date())
        
        // 특정 날짜에 대한 할 일 데이터를 가져옴
        self.userRef.child("todoList/todo/\(today)").observeSingleEvent(of: .value, with: { snapshot in
            guard let todoArrs = snapshot.children.allObjects as? [DataSnapshot] else {
                // 데이터가 없으면 progressData를 0으로 설정
                completion(progressData)
                return
            }
            
            for (_, todoArr) in todoArrs.enumerated() {
//                let goalData = self.goalListArray[key][1] as! [String: Any]
                
                for child in todoArr.children {
                    guard let todoSnap = child as? DataSnapshot, let todo = todoSnap.value as? [Any] else {
                        continue
                    }
                    todoCount += 1
                    if let isDone = todo[1] as? Bool, isDone {
                        doneCount += 1
                    }
                }
            }
            
            if todoCount != 0 {
                progressData = Int(Float(doneCount) / Float(todoCount) * 100)
            } else {
                progressData = 0
            }
            
            completion(progressData)
        }) { error in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(progressData)
        }
    }

    
    func setRoomDirty(completion: @escaping (Int, [String: [String: Any]]) -> Void) {
        var degreeData: Int! = 0
        var spriteData: [String: [String: Any]] = [:]
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        let date = self.dateFormatter(date: yesterday!)
        var todoCount = 0
        var doneCount = 0
        
        self.userRef.child("dirty/\(date)").observeSingleEvent(of: .value, with: { (snapshot) in
            if !snapshot.exists() { // 데이터가 존재하지 않는 경우
                
                self.getGoals() { goal in
                    self.getTodoByDate(date: date) { todoData in
                        for todo in todoData {
                            todoCount += todo.count
                            
                            for value in todo {
                                let isDone = value[1] as! Bool
                                if isDone {
                                    doneCount += 1
                                }
                            }
                        }
                        
                        if todoCount != 0 && doneCount != 0 {
                            degreeData = 10 - Int(Float(doneCount)/Float(todoCount) * 10)
                        }
                        else if todoCount == 0 { // 전 날에 애초에 할 일 목록이 없었으면 쓰레기 없음
                            degreeData = 0
                        }
                        else {
                            degreeData = 10
                        }
                        
                        self.userRef.child("dirty/\(date)").setValue(degreeData)
                        
                        self.userRef.child("dirty/total").observeSingleEvent(of: .value, with: { (snapshot) in
                            let totalData: Int!
                            
                            if !snapshot.exists() {
                                totalData = 0
                            }
                            else {
                                totalData = snapshot.value as? Int
                            }
                            
                            // total 더러움 합치기
                            degreeData = max(0, min(degreeData + totalData, 10))
                            // 전 날에 접속한 기록이 없는 사용자에게 패널티
                            degreeData = max(0, min(degreeData + 3, 10))
                            
                            self.userRef.child("dirty/total").setValue(degreeData)
                            
                            self.userRef.child("dirty/sprite/list").observeSingleEvent(of: .value, with: { (snapshot) in
                                guard let spriteList = snapshot.value as? [String: [String: Any]] else {
                                    print("No dirtySprite available.")
                                    completion(degreeData, spriteData)
                                    return
                                }
                                spriteData = spriteList
                                
                                self.dirtyCount = degreeData
                                self.dirtySpriteData = spriteData
                                completion(degreeData, spriteData)
                            }) { (error) in
                                print("Error getting dirty data: \(error.localizedDescription)")
                                completion(degreeData, spriteData)
                            }
                        }) { (error) in
                            print("Error getting dirty data: \(error.localizedDescription)")
                            completion(degreeData, spriteData)
                        }
                    }
                }
            }
            else {  // 이미 설정된 쓰레기가 있는 경우
                self.userRef.child("dirty/total").observeSingleEvent(of: .value, with: { (snapshot) in
                    guard let dirtyData = snapshot.value as? Int else {
                        print("No dirty available.")
                        completion(degreeData, spriteData)
                        return
                    }
                    degreeData = dirtyData
                    
                    self.userRef.child("dirty/sprite/list").observeSingleEvent(of: .value, with: { (snapshot) in
                        guard let spriteList = snapshot.value as? [String: [String: Any]] else {
                            print("No dirtySprite available.")
                            completion(degreeData, spriteData)
                            return
                        }
                        spriteData = spriteList
                        
                        self.dirtyCount = degreeData
                        self.dirtySpriteData = spriteData
                        completion(degreeData, spriteData)
                    }) { (error) in
                        print("Error getting dirty data: \(error.localizedDescription)")
                        completion(degreeData, spriteData)
                    }
                    
                    
                }) { (error) in
                    print("Error getting dirty data: \(error.localizedDescription)")
                    completion(degreeData, spriteData)
                }
            }
        })
    }
    
    func updateRoomDirty(dirty: Int, spriteList: [String: [String: Any]], index: Int, completion: @escaping (Int, [String: [String: Any]]) -> Void) {
        var degreeData: Int = dirty
        var spriteData: [String: [String: Any]] = spriteList
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        _ = self.dateFormatter(date: yesterday!)

        if index >= 0 { // 청소한 경우
            let key = "dirtySprite\(index)"
            if spriteData[key] != nil { // key가 유효한지 확인
                degreeData -= 1
                spriteData.removeValue(forKey: key)
                self.userRef.child("dirty/sprite/list/\(key)").removeValue()
            } else {
                print("Error: key out of bounds")
                completion(degreeData, spriteData)
                return
            }
        }
        else if index == -1 {
            self.userRef.child("dirty/sprite/list").setValue(spriteData)
        }
        
        self.userRef.child("dirty/total").setValue(degreeData)
        
        self.dirtyCount = degreeData
        self.dirtySpriteData = spriteData
        completion(degreeData, spriteData)
    }

    
    func getShop(completion: @escaping ([String: [Item]]?) -> Void) {
        var data: [String: [Item]] = [
            "wall": [Item(imageName: "wall_01_01", price: 20, isPurchased: true, isPlaced: true)],
            "floor": [Item(imageName: "floor_01_01", price: 20, isPurchased: true, isPlaced: true)],
            "molding": [Item(imageName: "molding_01_01", price: 10, isPurchased: true, isPlaced: true)]
        ]
        
        self.shopRef.child("item").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let shopData = snapshot.value as? NSDictionary else {
                completion(data)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            
            for (categoryKey, itemsData) in shopData {
                let category = itemsData as! NSDictionary
                var innerData: [Item] = []
                
                for (itemKey, itemData) in category {
                    let item = itemData as! [String: Int]
                    
                    for (colorKey, price) in item {
                        let imageName = "\(categoryKey)_\(itemKey)_\(colorKey)"
                        var isPurchased: Bool = false
                        var isPlaced: Bool = false
                        
                        dispatchGroup.enter()
                        self.userRef.child("inventory/\(categoryKey)/\(itemKey)/\(colorKey)").observeSingleEvent(of: .value, with: { (snapshot) in
                            if snapshot.exists() {
                                isPurchased = true
                            }
                            dispatchGroup.leave()
                        }) { error in
                            print("Error getting inventory data: \(error.localizedDescription)")
                            dispatchGroup.leave()
                        }
                        
                        dispatchGroup.enter()
                        self.userRef.child("inventory/placed/\(categoryKey)").observeSingleEvent(of: .value, with: { (snapshot) in
                            if let placedData = snapshot.value as? String, placedData == imageName {
                                isPlaced = true
                            }
                            dispatchGroup.leave()
                        }) { error in
                            print("Error getting inventory data: \(error.localizedDescription)")
                            dispatchGroup.leave()
                        }
                        
                        dispatchGroup.notify(queue: .main) {
                            innerData.append(Item(imageName: imageName, price: price, isPurchased: isPurchased, isPlaced: isPlaced))
                            data[categoryKey as! String] = innerData
                        }
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.shopList = data
                completion(data)
            }
        }) { error in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(data)
        }
    }
    
    func purchaseItem(categoryIndex: Int, itemIndex: Int, completion: @escaping ([String: [Item]]?) -> Void) {
        var data = self.shopList
        let category = categoryTitle[categoryIndex][0] as! String
        let imageName = data[category]?[itemIndex].imageName
        let keys = imageName?.split(separator: "_")
        
        // 인벤토리에 추가
        self.userRef.child("inventory/\(category)/\(keys![1])/\(keys![2])").setValue(imageName)
        data[category]?[itemIndex].isPurchased = true
        
        self.shopList = data
        completion(data)
    }
    
    func updatePlacement(categoryIndex: Int, itemIndex: Int, state: Bool, completion: @escaping ([String: [Item]]?) -> Void) {
        var data = self.shopList
        let category = categoryTitle[categoryIndex][0] as! String
        let imageName = data[category]?[itemIndex].imageName
        _ = imageName?.split(separator: "_")
        
        // 아이템 배치하기
        self.userRef.child("inventory/placed/\(category)").setValue(imageName)
        
        // 선택한 카테고리의 아이템을 전부 보관 후
        for i in 0 ..< data[category]!.count {
            data[category]?[i].isPlaced = false
        }
        
        // 선택된 아이템만 다시 배치
        if category != "wall" && category != "floor" && category != "molding" {
            data[category]?[itemIndex].isPlaced = state
            
            if state == false {
                self.userRef.child("inventory/placed/\(category)").removeValue()
            }
        }
        else {
            data[category]?[itemIndex].isPlaced = true
        }
        
        self.shopList = data
        completion(data)
    }
    
    func getPoint(completion: @escaping (Int) -> Void) {
        var data = 0
        
        self.userRef.child("point").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let point = snapshot.value as? [String:Int] else {
                print("No point available.")
                let date = self.dateFormatter(date: Date())
                self.userRef.child("point/\(date)").setValue(0)
                self.userRef.child("point/total").setValue(0)
                
                completion(data)
                return
            }
            
            data = point["total"]! as Int
            self.point = data
            completion(data)
        }) { (error) in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(data)
        }
    }
    
    func updatePoint(change: Int, cancel: Bool, completion: @escaping (Int) -> Void) {
        var pointData = self.point
        let date = self.s_date!
        
        self.userRef.child("point").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let point = snapshot.value as? [String:Int] else {
                print("No point available.")
                completion(pointData!)
                return
            }
            
            let todayPoint = (point["\(String(describing: date))"] ?? 0) as Int
            let updatedTodayPoint = todayPoint + change
            let updateTotalPoint = point["total"]! as Int + change
            
            if change > 0 { // 포인트가 추가 되는 경우: 할일 완료
                // 포인트 업데이트 전 valid한 값인지 확인: 1. 오늘 얻은 포인트가 300 이하여야 함, 2. 최대 999999999999 포인트까지 얻을 수 있음
                if (updatedTodayPoint <= 300) && (updateTotalPoint <= 999999999999) {
                    pointData = updateTotalPoint // 490
                    
                    if pointData! >= 0 && updatedTodayPoint >= 0 {
                        self.userRef.child("point/\(String(describing: date))").setValue(updatedTodayPoint)
                        self.userRef.child("point/total").setValue(pointData)
                    }
                }
                else if (updatedTodayPoint > 300) { // 오늘 얻을 수 있는 포인트를 다 얻은 경우
                    pointData = -1
                }
                else if (updateTotalPoint <= 999999999999) { // 최대 포인트에 도달한 경우
                    pointData = -2
                }
            }
            else if change < 0 { // 포인트가 감소 되는 경우: 아이템 구매
                // 포인트 업데이트 전 valid한 값인지 확인: 1. 최종 포인트가 0 미만으로 떨어지면 안됨
                if (0 <= updateTotalPoint) {
                    pointData! += change
                    
                    if pointData! >= 0 {
                        self.userRef.child("point/total").setValue(pointData)
                        
                        if cancel && (updatedTodayPoint >= 0) {
                            self.userRef.child("point/\(date)").setValue(updatedTodayPoint)
                        }
                    }
                }
                else if (updateTotalPoint < 0) { // 최종 포인트가 마이너스가 되는 경우
                    pointData = -3
                }
            }
            
            if pointData! >= 0 {
                self.point = pointData
            }
            completion(pointData!)
        }) { (error) in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(pointData!)
        }
    }
    
    // MARK: - realtime database에서 todo list 불러오기
    // MARK: 목표 관리
    func getGoals(completion: @escaping ([Int: [String: Any]]) -> Void) {
        self.userRef.child("todoList/goal").observeSingleEvent(of: .value, with: { snapshot in
            var goalData: [Int: [String: Any]] = [:]
            for case let child as DataSnapshot in snapshot.children {
                if let key = Int(child.key), let data = child.value as? [String: Any] {
                    goalData[key] = data
                }
            }
            self.goalDictionary = goalData
            completion(goalData)
        }) { error in
            print("Error getting todo data: \(error.localizedDescription)")
            completion([:])
        }
    }

    
    func getOngoingGoals(completion: @escaping ([Int: [String: Any]]) -> Void) {
        var goalData: [Int: [String: Any]] = [:]
        self.userRef.child("todoList/goal").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let goalSnap = snapshot.children.allObjects as? [DataSnapshot] else {
                print("goalsArr format is not as expected. Maybe empty.")
                completion(goalData)
                return
            }
            
            for (key, goal) in goalSnap.enumerated() {
                let data = goal.value as! [String: Any]
                if let ongoing = data["ongoing"] as? Bool, ongoing {
                    goalData[key] = data
                }
            }
            
            self.goalDictionary = goalData
            completion(goalData)
        }) { (error) in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(goalData)
        }
    }

    
    func addGoal(title: String, completion: @escaping ([Int: [String: Any]], [[[Any]]]) -> Void) {
        self.userRef.child("todoList/goal").observeSingleEvent(of: .value, with: { snapshot in
            var maxDatabaseKey = -1
            for child in snapshot.children.allObjects as! [DataSnapshot] {
                if let databaseKey = Int(child.key) {
                    maxDatabaseKey = max(databaseKey, maxDatabaseKey)
                }
            }
            let newKey = maxDatabaseKey + 1
            let data = ["title": title, "ongoing": true] as [String: Any]
            self.userRef.child("todoList/goal/\(newKey)").setValue(data)
            var goalData = self.goalDictionary
            goalData[newKey] = data
            
            var todoData = self.todoListArray
            todoData.append([])
            
            self.goalDictionary = goalData
            self.todoListArray = todoData
            completion(goalData, todoData)
        }) { error in
            print("Error getting todo data: \(error.localizedDescription)")
        }
    }
    
    func updateGoalTitle(key: Int, title: String, completion: @escaping ([Int: [String: Any]]) -> Void) {
        self.userRef.child("todoList/goal/\(key)/title").setValue(title)
        var goalData = self.goalDictionary
        goalData[key]?["title"] = title
        self.goalDictionary = goalData
        completion(goalData)
    }
    
    func updateGoalState(date: String, key: Int, state: Bool, completion: @escaping ([Int: [String: Any]]) -> Void) {
        var goalData = self.goalDictionary
        goalData[key]?["ongoing"] = state
        self.userRef.child("todoList/goal/\(key)/ongoing").setValue(state)
        
        if state == false { // 보관하는 경우
            goalData[key]?["endDate"] = date
            self.userRef.child("todoList/goal/\(key)/endDate").setValue(date)
        } else {    // 복구하는 경우
            goalData[key]?["endDate"] = date
            self.userRef.child("todoList/goal/\(key)/endDate").removeValue()
        }
        self.goalDictionary = goalData
        completion(goalData)
    }

    func removeGoal(key: Int, completion: @escaping ([Int: [String: Any]], [[[Any]]]) -> Void) {
        var goalData = self.goalDictionary
        var todoData = self.todoListArray
        
        goalData.removeValue(forKey: key)
        todoData.removeAll { $0.first?.first as? Int == key }
        
        self.userRef.child("todoList/goal/\(key)").removeValue()
        self.userRef.child("todoList/todo").observeSingleEvent(of: .value, with: { snapshot in
            for case let dateSnapshot as DataSnapshot in snapshot.children {
                self.userRef.child("todoList/todo/\(dateSnapshot.key)/\(key)").removeValue()
            }
            self.goalDictionary = goalData
            self.todoListArray = todoData
            completion(goalData, todoData)
        }) { error in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(goalData, todoData)
        }
    }
    
    func moveGoal(from: Int, to: Int, completion: @escaping ([Int: [String: Any]]) -> Void) {
//        let fromSection = from.section
        let fromRow = from
//        let toSection = to.section
        let toRow = to
        
//        let fromDatabseKey = self.goalListArray[fromRow][0] as! Int
//        let toDatabseKey = self.goalListArray[toRow][0] as! Int
        
        self.userRef.child("todoList/todo").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let allTodos = snapshot.children.allObjects as? [DataSnapshot] else {
                print("No todos available.")
                return
            }
            
            for (_, allData) in allTodos.enumerated() {
                let dateKey = allData.key // ex. 2024-05-15
                
                self.getTodoByDate(date: dateKey) { data in
                    var todoData = data
                    
                    let movedData = todoData[fromRow]
                    todoData.remove(at: fromRow)
                    todoData.insert(movedData, at: toRow)
                    
                    self.userRef.child("todoList/todo/\(dateKey)").setValue(todoData)
                }
            }
        }) { (error) in
            print("Error getting todo data: \(error.localizedDescription)")
        }
        
        var goalData: [Int: [String: Any]] = [:]
        var goalArrData: [[Any]] = self.goalListArray
        var movedGoalData: [Any] = []
        
        let movedGoal = goalArrData[fromRow]
        goalArrData.remove(at: fromRow)
        goalArrData.insert(movedGoal, at: toRow)
        
        for goal in goalArrData {
            movedGoalData.append(goal[1])
        }
        self.userRef.child("todoList/goal").setValue(movedGoalData)
        
        self.getGoals() { data in
            goalData = data
            
            self.goalDictionary = goalData
            completion(goalData)
        }
    }
    
    // MARK: 투두 관리
    func getTodoByDate(date: String, completion: @escaping ([[[Any]]]) -> Void) {
        var todoData: [[[Any]]] = []
        var goalKeys: [Int] = []
        
        for _ in 0 ..< self.goalDictionary.count {
            todoData.append([])
        }
        
        for goal in self.goalListArray {
            goalKeys.append(goal[0] as! Int)
        }
        
        self.userRef.child("todoList/todo/\(date)").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let todoArrs = snapshot.children.allObjects as? [DataSnapshot] else {
                print("Data format is not as expected. Maybe empty.")
                // 데이터가 없으면 빈 배열 반환
                completion(todoData)
                return
            }
            
            for (_, todoArr) in todoArrs.enumerated() {
                guard let key = goalKeys.firstIndex(of: Int(todoArr.key)!) else {
                    continue
                }
                
                for child in todoArr.children {
                    guard let todoSnap = child as? DataSnapshot, let todo = todoSnap.value as? [Any] else {
                        continue
                    }
                    todoData[key].append(todo)
                }
            }
            
            self.todoListArray = todoData
            completion(todoData)
        }) { (error) in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(todoData)
        }
    }
    
    func getNumberOfEvents(date: String, completion: @escaping (Int) -> Void) {
        var data: Int = 0
        
        DatabaseUtils.shared.getGoals { goalData in
            let filteredData = goalData.filter { key, goal in
                if let endDate = goal["endDate"] as? String, let ongoing = goal["ongoing"] as? Bool {
                    return ongoing || endDate.isEmpty
                }
                return true
            }
            
            self.userRef.child("todoList/todo/\(date)").observeSingleEvent(of: .value, with: { (snapshot) in
                guard let todoArrs = snapshot.children.allObjects as? [DataSnapshot] else {
                    print("Data format is not as expected. Maybe empty.")
                    // 데이터가 없으면 빈 배열 반환
                    completion(data)
                    return
                }
                
                for (_, todoArr) in todoArrs.enumerated() {
                    if filteredData[Int(todoArr.key)!] != nil {
                        
                        for child in todoArr.children {
                            guard let todoSnap = child as? DataSnapshot, let todo = todoSnap.value as? [Any] else {
                                continue
                            }
                            
                            let isDone = todo[1] as! Bool
                            if isDone == false {
                                data += 1
                            }
                        }
                    }
                    
                }
                
                completion(data)
            }) { (error) in
                print("Error getting todo data: \(error.localizedDescription)")
                completion(data)
            }
        
        }
    }
    
    func getAllTodo(completion: @escaping ([[[Any]]]) -> Void) {
        var data: [[[Any]]] = []
        
        for _ in 0 ..< self.goalDictionary.count {
            data.append([])
        }
        
        var goalKeys: [Int] = []
        for goal in self.goalListArray {
            goalKeys.append(goal[0] as! Int)
        }
        
        self.userRef.child("todoList/todo").observeSingleEvent(of: .value, with: { (snapshot) in
            guard let allTodos = snapshot.children.allObjects as? [DataSnapshot] else {
                print("No todos available.")
                completion(data)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            
            for (_, todoArrs) in allTodos.enumerated() {
                let dateKey = todoArrs.key // ex. 2024-05-14
                dispatchGroup.enter()
                
                self.getTodoByDate(date: dateKey) { innerData in
                    for i in 0 ..< innerData.count {
                        let key = i
                        let todo = innerData[i]
                        
                        for j in 0 ..< todo.count {
                            let row = j
                            let section = goalKeys[key]
                            
                            if todo[j][1] as! Bool == false {
                                data[key].append([todo[j][0], todo[j][1], dateKey, section, row])
                            }
                        }
                    }
                    
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.todoListArray = data
                completion(data)
            }
        }) { (error) in
            print("Error getting todo data: \(error.localizedDescription)")
            completion(data)
        }
    }
    
    // 새로운 todo 저장
    func addTodo(date: String, index: IndexPath, databaseIndex: IndexPath, todoTitle: String, todoStatus: Bool, completion: @escaping ([[[Any]]]) -> Void) {
        var data = self.todoListArray
        
        let todoData = [todoTitle, todoStatus] as [Any]
        let section = index.section
        let row = index.row
        let databaseSection = databaseIndex.section
        let databaseRow = databaseIndex.row
        
        // Firebase에 데이터 저장
        self.userRef.child("todoList/todo/\(date)/\(databaseSection)/\(databaseRow)").setValue(todoData)
        
        // 테이블에 데이터 추가
        data[section].insert(todoData, at: row)
        
        self.todoListArray = data
        completion(data)
    }

    // todo 제거
    func removeTodo(date: String, index: IndexPath, databaseIndex: IndexPath, completion: @escaping ([[[Any]]]) -> Void) {
        var data: [[[Any]]] = self.todoListArray
        let section = index.section
        let row = index.row
        let databaseSection = databaseIndex.section
        _ = databaseIndex.row
        
        // 선택한 위치의 데이터를 로컬에서 제거
        data[section].remove(at: row)
        // db 업데이트
        self.userRef.child("todoList/todo/\(date)/\(databaseSection)").setValue(data[section])
        
        self.todoListArray = data
        completion(data)
    }
    
    func removeTodoAtAll(date: String, index: IndexPath, databaseIndex: IndexPath, completion: @escaping ([[[Any]]]) -> Void) {
        var data: [[[Any]]] = self.todoListArray
        let section = index.section
        let row = index.row
        let databaseSection = databaseIndex.section
        _ = databaseIndex.row
        
        // 선택한 위치의 데이터를 로컬에서 제거
        data[section].remove(at: row)
        
        var tempData = data[section]
        var removeIndex: [Any] = []
        for i in 0 ..< tempData.count {
            let tempDate = tempData[i][2] as! String
            if tempDate != date {
                removeIndex.append(i)
            }
            
            tempData[i].remove(at: 4)
            tempData[i].remove(at: 3)
            tempData[i].remove(at: 2)
        }
        
        for i in 0 ..< removeIndex.count {
            tempData.remove(at: i)
        }
        
        // db 업데이트
        self.userRef.child("todoList/todo/\(date)/\(databaseSection)").setValue(tempData)
        
        self.todoListArray = data
        completion(data)
    }
    
    func updateTodoCheck(date: String, index: IndexPath, databaseIndex: IndexPath, todoStatus: Bool, completion: @escaping ([[[Any]]], Int) -> Void) {
        var todoData: [[[Any]]] = self.todoListArray
        var pointData: Int = self.point
        let section = index.section
        let row = index.row
        let databaseSection = databaseIndex.section
        let databaseRow = databaseIndex.row
        
        // 업데이트
        todoData[section][row][1] = todoStatus
        self.userRef.child("todoList/todo/\(date)/\(databaseSection)/\(databaseRow)/1").setValue(todoStatus)
        
        
        if todoStatus {
            self.updatePoint(change: 10, cancel: false) { updatedPointData in
                pointData = updatedPointData
                
                self.point = pointData
                self.todoListArray = todoData
                completion(todoData, pointData)
            }
        }
        else {
            self.updatePoint(change: -10, cancel: true) { updatedPointData in
                pointData = updatedPointData
                
                self.point = pointData
                self.todoListArray = todoData
                completion(todoData, pointData)
            }
        }
        
        self.todoListArray = todoData
        completion(todoData, pointData)
    }
    
    func updateTodoContent(date: String, index: IndexPath, databaseIndex: IndexPath, todoTitle: String, completion: @escaping ([[[Any]]]) -> Void) {
        var todoData: [[[Any]]] = self.todoListArray
        let section = index.section
        let row = index.row
        let databaseSection = databaseIndex.section
        let databaseRow = databaseIndex.row
        
        todoData[section][row][0] = todoTitle
        self.userRef.child("todoList/todo/\(date)/\(databaseSection)/\(databaseRow)/0").setValue(todoTitle)
        
        self.todoListArray = todoData
        completion(todoData)
    }
    
    func moveTodo(date: String, from: IndexPath, to: IndexPath, fromDatabase: IndexPath, toDatabase: IndexPath, completion: @escaping ([[[Any]]]) -> Void) {
        var todoData: [[[Any]]] = self.todoListArray
        let date = date
        let fromSection = from.section, fromRow = from.row
        let toSection = to.section, toRow = to.row
        
        let movedData = todoData[fromSection][fromRow]
        todoData[fromSection].remove(at: fromRow)
        todoData[toSection].insert(movedData, at: toRow)
        
        self.userRef.child("todoList/todo/\(date)/\(fromDatabase.section)").setValue(todoData[fromSection])
        self.userRef.child("todoList/todo/\(date)/\(toDatabase.section)").setValue(todoData[toSection])
        
        self.todoListArray = todoData
        completion(todoData)
    }
    
    func dateFormatter(date: Date) -> String {
        // DateFormatter 생성
        let dateFormatter = DateFormatter()
        
        // 지역 설정
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        
        // 날짜 형식 지정
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Date를 문자열로 변환
        let dateString = dateFormatter.string(from: date)
        
        return dateString
    }
}


let categoryTitle: [[Any]] = [
    ["wall", "벽지"], ["floor", "바닥"], ["molding", "몰딩"], ["window", "창문"], ["rug", "러그"],
    ["table", "테이블"], ["chair", "의자"], ["sofa", "소파"],
    ["lightning", "조명"], ["plant", "식물"], ["catTower", "캣타워"]
]

struct Goal {
    var ongoing: Bool
    var title: String
}

struct PlacedItmes {
    var wall: String
    var floor: String
    var molding: String
    var window: String
    
    var rug: String
    var table: String
    var chair: String
    var sofa: String
    var lightning: String
    var plant: String
    var catTower: String
}

struct Item {
    var imageName: String
    var price: Int
    var isPurchased: Bool
    var isPlaced: Bool
}

struct Cat {
    var imageName: String
    var catName: String
    var description: String
    var point: Int
}

struct Friend {
    var profileImage: String
    var email: String
    var state: String
}

struct FriendRoom {
    var goalDictionary: [Int: [String: Any]]
    var goalListArray: [[Any]] = []
    var todoListArray: [[[Any]]] = [[]]
    var placedItems: PlacedItmes
    
    var dirtyCount: Int?
    var dirtySpriteData: [String: [String: Any]] = [:]
    var progress: Int?
}

class CatInfo {
    static let catCollectionList: [Int:Cat] = [
        1: Cat(imageName: "cat01_sitting_01", catName: "나비", description: "애교 많고 호기심 많은 고양이로, 사람들과 장난을 즐깁니다.", point: 0),
        2: Cat(imageName: "cat02_sitting_01", catName: "코코", description: "조용하고 침착한 고양이로, 주위를 차분하게 관찰하며 행동해요.", point: 100),
        3: Cat(imageName: "cat03_sitting_01", catName: "까미", description: "경계심이 강하고 겁이 많아 바람 소리에도 깜짝 놀랍니다.", point: 100),
        4: Cat(imageName: "cat04_sitting_01", catName: "치즈", description: "똑똑하고 애교 많은 고양이로, 사람들의 관심을 끌기 좋아해요.", point: 200),
        5: Cat(imageName: "cat05_sitting_01", catName: "망고", description: "호기심 많고 사교적인 고양이로, 새로운 사람들과 빠르게 친해져요.", point: 200),
        6: Cat(imageName: "cat06_sitting_01", catName: "모모", description: "호기심 많고 민첩한 고양이로, 높은 곳을 탐험하는 것을 좋아해요.", point: 200),
        7: Cat(imageName: "cat07_sitting_01", catName: "절미", description: "조용하고 침착한 고양이로, 주위를 차분하게 관찰하며 행동해요.", point: 400),
        8: Cat(imageName: "cat08_sitting_01", catName: "양말이", description: "독립적이고 자유로운 고양이로, 주변의 환경에 대해 호기심이 많습니다.", point: 400),
        9: Cat(imageName: "cat09_sitting_01", catName: "하루", description: "매우 착하고 순한 성격을 갖고 있습니다.", point: 500),
        10: Cat(imageName: "cat10_sitting_01", catName: "보리", description: "용감하고 활동적인 고양이로, 놀이시간을 즐기며 늘 에너지 넘칩니다.", point: 500),
        11: Cat(imageName: "cat11_sitting_01", catName: "루나", description: "부드럽고 다정한 고양이로, 사랑스러운 성격을 가지고 있어요.", point: 800),
        12: Cat(imageName: "cat12_sitting_01", catName: "쿠키", description: "호기심 많고 장난기 많은 고양이로, 새로운 것에 항상 관심이 많아요.", point: 800)
    ]
    
    static var catTamedList: [String: String] = [:] {
        didSet {
            // 키를 정렬
            let sortedKeys = catTamedList.keys.sorted()
            
            // 정렬된 키를 사용하여 정렬된 딕셔너리 생성
            let sortedDict = sortedKeys.reduce(into: [String: String]()) { dict, key in
                dict[key] = catTamedList[key]
            }
            
            // 정렬된 딕셔너리로 catTamedList 업데이트
            catTamedList = sortedDict
        }
    }
}
