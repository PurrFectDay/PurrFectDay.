//
//  ManageFriendViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/06/08.
//

import UIKit
import FirebaseAuth
import SpriteKit
import AVFAudio

class ManageFriendViewController: UIViewController {
    @IBAction func goBack(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var friendTableView: UITableView!
    
    var handle: AuthStateDidChangeListenerHandle?
    var ref: DatabaseReference!
    let currentUserId = Auth.auth().currentUser!.uid
    
    var followList: [Friend] = DatabaseUtils.shared.followList
    var followerList: [Friend] = DatabaseUtils.shared.followerList
    var f4fList: [Friend] = DatabaseUtils.shared.f4fList
    var selectedFriend: Friend?
    
    var followers: [String] = []
    var following: [String] = []
    var f4f: [String] = []
    
    @IBAction func searchFriend(_ sender: UIButton) {
        searchBarSearchButtonClicked(self.searchBar)
    }
    
    override func viewDidLoad() {
        // [START auth_listener] 리스너 연결
        handle = Auth.auth().addStateDidChangeListener { auth, user in
            // [START_EXCLUDE]
            // [END_EXCLUDE]
        }
        // Firebase Database Reference 초기화
        ref = Database.database().reference()
        
        super.viewDidLoad()
        // 키보드 외부 터치 시 키보드 내리기
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        self.searchBar.delegate = self
        self.friendTableView.delegate = self
        self.friendTableView.dataSource = self
        
        self.friendTableView.backgroundColor = .clear
        
        
        // 내가 팔로우한 사용자 목록 감시
        let userRef = ref.child("users/\(currentUserId)/friend")
        userRef.observe(.value) { snapshot in
            print("DEBUG: snapshot key is \(snapshot.key)")
            
            DatabaseUtils.shared.getFollow(completion: { data in
                self.followList = data
                self.friendTableView.reloadData()
            })
            
            DatabaseUtils.shared.getFollower(completion: { data in
                self.followerList = data
                self.friendTableView.reloadData()
            })
            
            DatabaseUtils.shared.getF4F(completion: { data in
                self.f4fList = data
                self.friendTableView.reloadData()
            })
            
            
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // [START remove_auth_listener] 리스너 분리
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ManageToVisitSegue" {
            if let nextVC = segue.destination as? VisitFriendViewController {
                nextVC.preVC = "Manage"
                if let selectedFriend = self.selectedFriend {
                    nextVC.friend = selectedFriend
                }
            }
        }
    }
}

extension ManageFriendViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // 키보드 내리기
        guard let email = searchBar.text, !email.isEmpty else {
            print("Please enter an email.")
            self.view.makeToast("이메일을 입력해주세요.", duration: 3.0, position: .center)
            return
        }
        
        if email == DatabaseUtils.shared.user?.email {
            self.view.makeToast("자신을 이웃으로 추가할 수 없습니다.", duration: 3.0, position: .center)
            return
        }
        
        isValidEmail(email: email) { [weak self] isValid, domain, id in
            guard let self = self else { return }
            
            if isValid! { // 유효한 이메일 형식
                searchUserByEmail(domain: domain!, id: id!) { [weak self] isExist in
                    if isExist == true {   // 이메일이 존재함
                        AlertUtils.showYesNoAlert(view: self!, title: "서로이웃 요청", message: "\(email)에게 서로이웃 요청을 보내시겠습니까?", completion: { yes in
                            if yes {
                                self!.view.makeToast("\(email)에게 서로이웃 요청을 보냈습니다.", duration: 3.0, position: .center)
                                DatabaseUtils.shared.requestFriend(friendEmail: email) { data in
                                    self!.followList = data
                                    self!.friendTableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                                }
                                return
                            }
                            else {
                                return
                            }
                        })
                    }
                    else if isExist == false {
                        print("User not found.")
                        self!.view.makeToast("해당 이메일로 사용자를 찾을 수 없습니다.", duration: 3.0, position: .center)
                        return
                    }
                    else if isExist == nil {
                        self!.view.makeToast("이미 서로이웃이거나 요청을 주고받은 상대입니다.", duration: 3.0, position: .center)
                        return
                    }
                }
            }
            else {
                self.view.makeToast("올바른 형식의 이메일을 입력해주세요.", duration: 3.0, position: .center)
                return
            }
        }
    }
}

class FollowCell: UITableViewCell {
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    
    var cancelAction: (() -> Void)?
    
    @IBAction func cancelFollow(_ sender: UIButton) {
        cancelAction?()
    }
}

class FollowerCell: UITableViewCell {
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var emailLabel: UILabel!
    
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var rejectButton: UIButton!
    
    
    var acceptAction: (() -> Void)?
    
    @IBAction func acceptFollow(_ sender: UIButton) {
        acceptAction?()
    }
    
    var rejectAction: (() -> Void)?
    @IBAction func rejectFollow(_ sender: UIButton) {
        rejectAction?()
    }
}


class F4FCell: UITableViewCell {
    weak var delegate: F4FCellDelegate?
    var friend: Friend?
    
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    @IBOutlet weak var visitButton: UIButton!
    @IBOutlet weak var unfollowButton: UIButton!
    @IBOutlet weak var confirmButton: UIButton!
    
    
    @IBAction func visitFriend(_ sender: UIButton) {
        if let friend = friend {
            delegate?.didTapVisitButton(friend: friend)
        }
    }
    
    func configure(with friend: Friend) {
        self.friend = friend
    }
    
    var unfollowAction: (() -> Void)?
    @IBAction func unfollowFriend(_ sender: UIButton) {
        unfollowAction?()
    }
    
    var confirmAction: (() -> Void)?
    @IBAction func confirm(_ sender: UIButton) {
        confirmAction?()
    }
}

protocol F4FCellDelegate: AnyObject {
    func didTapVisitButton(friend: Friend)
}
extension ManageFriendViewController: F4FCellDelegate {
    func didTapVisitButton(friend: Friend) {
        self.selectedFriend = friend
        performSegue(withIdentifier: "ManageToVisitSegue", sender: self)
    }
}

extension ManageFriendViewController: UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - section
    // 섹션 수 반환
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    // 섹션 헤더 설정
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "내가 서로이웃 요청을 보낸 사용자"
        case 1:
            return "나에게 서로이웃 요청을 보낸 사용자"
        case 2:
            return "서로이웃"
        default:
            return ""
        }
    }
    
    // 각 섹션의 행 수 반환
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.followList.count
        case 1:
            return self.followerList.count
        case 2:
            return self.f4fList.count
        default:
            return 0
        }
    }
    
    // 셀 높이 설정
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FollowCell") as! FollowCell
            let friend = self.followList[indexPath.row]

            cell.profileImage.setImage(UIImage(named: friend.profileImage)!)
            cell.emailLabel.text = friend.email
            cell.backgroundColor = .clear
            
            // 초기화
            cell.infoLabel.isHidden = true
            cell.cancelButton.setTitle("취소", for: .normal)

            if friend.state == "true" {   // 상대방이 아직 응답하지 않음
                cell.infoLabel.isHidden = true
            } else if friend.state == "false" { // 상대방이 거절함
                cell.infoLabel.isHidden = false
                cell.cancelButton.setTitle("확인", for: .normal)
            }

            cell.cancelAction = { [weak self] in
                DatabaseUtils.shared.cancelFollow(email: friend.email, completion: { data in
                    self!.followList = data!
                    tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
                })
            }

            return cell

        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "FollowerCell") as! FollowerCell
            let friend = self.followerList[indexPath.row]

            cell.profileImage.setImage(UIImage(named: friend.profileImage)!)
            cell.emailLabel.text = friend.email
            cell.backgroundColor = .clear

            cell.acceptButton.isHidden = false
            cell.rejectButton.isHidden = false

            cell.acceptAction = { [weak self] in
                DatabaseUtils.shared.acceptFollow(email: friend.email, completion: { followerData, f4fData in
                    self!.followerList = followerData
                    self!.f4fList = f4fData
                    self!.friendTableView.reloadSections(IndexSet([1, 2]), with: .automatic)
                })
            }

            cell.rejectAction = { [weak self] in
                DatabaseUtils.shared.rejectFollow(email: friend.email, completion: { followerData in
                    self!.followerList = followerData!
                    self!.friendTableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                })
            }

            return cell

        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "F4FCell") as! F4FCell
            let friend = self.f4fList[indexPath.row]

            cell.profileImage.setImage(UIImage(named: friend.profileImage)!)
            cell.emailLabel.text = friend.email
            cell.backgroundColor = .clear
            
            // 초기화
            cell.infoLabel.isHidden = true
            cell.confirmButton.isHidden = true
            cell.visitButton.isHidden = false
            cell.unfollowButton.isHidden = false

            
            if friend.state == "new" {   // 아직 확인을 안했음
                cell.infoLabel.isHidden = false
                cell.confirmButton.isHidden = false
                cell.infoLabel.text = "상대방이 요청을 수락했습니다."
                
                cell.visitButton.isHidden = true
                cell.unfollowButton.isHidden = true

                cell.confirmAction = { [weak self] in
                    DatabaseUtils.shared.confirmF4F(email: friend.email, completion: { f4fData in
                        self!.f4fList = f4fData!
                        self!.friendTableView.reloadData()
                    })
                }
            } else if friend.state == "true" { // 기존 맞팔 상대
                cell.infoLabel.isHidden = true
                cell.confirmButton.isHidden = true

                cell.visitButton.isHidden = false
                cell.unfollowButton.isHidden = false
                
                cell.unfollowAction = { [weak self] in
                    DatabaseUtils.shared.unfollowF4F(email: friend.email, completion: { f4fData in
                        self!.f4fList = f4fData!
                        self!.friendTableView.reloadData()
                    })
                }
                
            } else if friend.state == "false" { // 상대방이 팔로우 끊음
                cell.infoLabel.isHidden = false
                cell.confirmButton.isHidden = false
                cell.infoLabel.text = "상대방이 이웃을 끊었습니다."

                cell.visitButton.isHidden = true
                cell.unfollowButton.isHidden = true

                cell.confirmAction = { [weak self] in
                    DatabaseUtils.shared.unfollowF4F2(email: friend.email, completion: { f4fData in
                        self!.f4fList = f4fData!
                        self!.friendTableView.reloadData()
                    })
                }
            }

            

            cell.delegate = self
            cell.configure(with: friend)

            return cell

        default:
            let cell = UITableViewCell()
            cell.textLabel?.text = ""
            cell.backgroundColor = .clear
            return cell
        }
    }
}


extension ManageFriendViewController {
    func isValidEmail(email: String, completion: @escaping (Bool?, String?, String?) -> Void) {
        let id = email.split(separator: "@")
        guard id.count == 2 else {
            completion(false, nil, nil)
            return
        }
        
        let domain = id[1].split(separator: ".")
        guard domain.count == 2, domain[1] == "com" else {
            completion(false, nil, nil)
            return
        }
        
        completion(true, String(domain[0]), String(id[0]))
    }
    
    func searchUserByEmail(domain: String, id: String, completion: @escaping (Bool?) -> Void) {
        DatabaseUtils.shared.searchFriend(domain: domain, id: id) { data in
            completion(data)
        }
    }
}

class VisitFriendViewController: UIViewController, UITextFieldDelegate {
    @IBAction func goBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBOutlet weak var friendGameView: SKView!
    @IBOutlet weak var progressButton: UIButton!
    var circleProgressView: CircleProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    
    @IBOutlet weak var sendBubble: UIButton!
    @IBOutlet weak var bubbleTextField: UITextField!
    @IBOutlet weak var mainCatImage: UIImageView!
    @IBOutlet weak var friendTodoTableView: UITableView!
    
    @IBAction func sendBubble(_ sender: UIButton) {
        self.sendBubble.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
            self.sendBubble.isEnabled = true
        }
        
        let bubble = self.bubbleTextField.text
        
        if bubble == "" || bubble == nil {
            self.view.makeToast("내용을 입력해주세요.", duration: 3.0, position: .top)
        }
        else {
            AlertUtils.showYesNoAlert(view: self, title: "확인", message: "한 번 보낸 메시지는 취소할 수 없습니다. 메시지를 보내겠습니까?", completion: { yes in
                if yes {
                    DatabaseUtils.shared.sendBubble(email: self.friend!.email, bubble: bubble!, completion: { })
                    
                    self.scene?.makeBubbleSprite(with: bubble!)
                    self.bubbleTextField.text = ""
                }
            })
        }
        
        
    }
    
    var preVC: String?
    var friend: Friend?
    
    var friendRoom: FriendRoom?
    var scene: FriendGameScene?
    
    var isTodoCheck = false
    var goalListArray: [[Any]] = []
    var goalDictionary: [Int: [String: Any]] = [:]
    var todoListArray: [[[Any]]] = []
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationItem.title = "\(friend!.email)의 홈"
        self.mainCatImage.setImage(UIImage(named: friend!.profileImage)!)
        
        // Setup progressButton
        progressButton.layer.cornerRadius = 50
        progressButton.layer.cornerRadius = progressButton.bounds.size.width / 2
        
        circleProgressView = CircleProgressView(frame: progressButton.bounds)
        circleProgressView.backgroundColor = .clear // 배경을 투명하게 설정
        circleProgressView.backgroundCircleColor = UIColor(named: "GrayGreen")! // 배경 원의 색상 설정
        circleProgressView.progressColor = UIColor(named: "DeepGreen")!         // 진행 원의 색상 설정
        progressButton.addSubview(circleProgressView)
        circleProgressView.progress = 0.0
        
        
        // Reset all data
        DatabaseUtils.shared.getF4FRoom(email: friend!.email, completion: { data in
            self.friendRoom = data!
            
            self.goalDictionary = self.friendRoom!.goalDictionary
            self.goalListArray = self.friendRoom!.goalListArray
            self.todoListArray = self.friendRoom!.todoListArray
            let progress = self.friendRoom?.progress
            
            self.friendTodoTableView.reloadData()
            
            if progress == 0 {
                self.animateProgress(to: 0)
            } else {
                self.animateProgress(to: CGFloat(progress!) / 100)
            }
            
            self.progressLabel.text = "\(progress ?? 0)%"
            
            if let view = self.friendGameView {
                self.scene = FriendGameScene(size: self.friendGameView.bounds.size)
                
                self.scene?.dirtyCount = self.friendRoom?.dirtyCount ?? 0
                self.scene?.dirtySpriteData = self.friendRoom?.dirtySpriteData ?? [:]
                self.scene?.placedItems = self.friendRoom?.placedItems
                
                let str = self.friend!.profileImage.split(separator: "_")[0]
                let length = str.count
                let startIndex = str.index(str.startIndex, offsetBy: length - 2)
                let catNum = String(str[startIndex...])
                self.scene?.catNum = catNum
                
                self.scene?.scaleMode = .aspectFill
                view.presentScene(self.scene)
                view.ignoresSiblingOrder = true
                view.layer.cornerRadius = 20
            }
        })
        
        let number = String(format: "%3d", 0)
        self.progressLabel.text = "\(number)%"
    }
    
    override func viewDidLoad() {
        // 키보드 외부 터치 시 키보드 내리기
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        self.friendTodoTableView.delegate = self
        self.friendTodoTableView.dataSource = self
        
        self.friendTodoTableView.layer.cornerRadius = 20
        
        // CustomHeaderFooterView를 등록
        self.friendTodoTableView.register(UINib(nibName: "CustomHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "CustomHeaderView")
        
        self.bubbleTextField.delegate = self
        
//        let backgroundImage = UIImage(named: "bubble")
//        bubbleTextField.background = backgroundImage
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // UITextField의 입력 글자 수를 제한하는 델리게이트 메서드
    @objc(textField:shouldChangeCharactersInRange:replacementString:) func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        if updatedText.count > 30 {
            // 최대 글자 수를 초과하는 경우 경고 메시지를 띄움
            self.view.makeToast("최대 30자까지 입력 가능합니다.", duration: 3.0, position: .top)
            return false
        }
        
        return true
    }
    
    private func updateProgressView() {
        DatabaseUtils.shared.getF4FRoom(email: self.friend!.email, completion: { data in
            let progress = data!.progress
            
            if progress == 0 {
                self.animateProgress(to: 0)
            } else {
                self.animateProgress(to: CGFloat(progress!) / 100)
            }
            
            self.progressLabel.text = "\(progress ?? 0)%"
        })
    }

    private func animateProgress(to progress: CGFloat) {
        self.circleProgressView.setProgress(progress, animated: true)
    }
}

class FriendToDoListCell: UITableViewCell {
    
    @IBOutlet weak var todoCheckButton: UIButton!
    @IBOutlet weak var todoTextField: UITextField!
}

extension VisitFriendViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.goalListArray.isEmpty ? 1 : self.goalListArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.goalListArray.isEmpty {
            return 0
        }
        if section >= 0 && section < self.todoListArray.count {
            return self.todoListArray[section].count
        }
        return 0
    }
    
    
    // 섹션 헤더 설정
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if self.goalListArray.isEmpty {
            return nil
        }
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "CustomHeaderView") as! CustomHeaderView
        let key = self.goalListArray[section][0] as! Int
        
        if let goal = self.goalDictionary[key], let title = goal["title"] as? String, let state = goal["ongoing"] as? Bool {
            let buttonText = title
            headerView.updateButton(title: buttonText, isOngoing: state)
            headerView.updateButtonsEnabledState(isOngoing: state)
            headerView.endDateLabel.isHidden = true
        }
        
        headerView.ellipsisButton.isHidden = true
        headerView.addTodoButton.backgroundColor = .clear
        headerView.addTodoButton.setTitleColor(UIColor(named: "OliveGreen"), for: .normal)
        
        return headerView
    }
    
    // 테이블 뷰의 헤더 뷰가 표시될 때 버튼의 상태를 설정하는 메서드 수정
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? CustomHeaderView else { return }

        // 버튼의 intrinsicContentSize 재계산
        headerView.addTodoButton.invalidateIntrinsicContentSize()
    }
    
    func shouldHideSection(section: Int) -> Bool {
        if !self.goalDictionary.isEmpty {
            let key = self.goalListArray[section][0] as! Int
            if let goal = self.goalDictionary[key], let state = goal["ongoing"] as? Bool, !state {
                return true
            }
        }
        
        return false
    }

    // 섹션 헤더 높이 설정
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return shouldHideSection(section: section) ? 0 : 44
    }
    
    // 섹션 푸터 높이 설정
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    // 셀 높이 설정
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        return shouldHideSection(section: indexPath.section) ? 0 : 44
        return 44
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 재사용 가능한 셀을 가져옴
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FriendToDoListCell") as? FriendToDoListCell else {
            fatalError("Failed to dequeue a ToDoListCell.")
        }
        
        // 각 cell의 todoTextField 텍스트의 내용을 각 todoListArray에 해당하는 "할 일" 내용으로 설정
        cell.todoTextField.text = (self.todoListArray[indexPath.section][indexPath.row][0] as! String)
        
        // 각 cell의 todoCheckButton을 각 todoListArray에 해당하는 Bool 타입에 따라 설정
        isTodoCheck = self.todoListArray[indexPath.section][indexPath.row][1] as! Bool
        
        if isTodoCheck == true {
            cell.todoCheckButton.setImage(UIImage(systemName: "square.inset.filled"), for: .normal)
        }
        else {
            cell.todoCheckButton.setImage(UIImage(systemName: "square"), for: .normal)
        }
        
        cell.selectionStyle = UITableViewCell.SelectionStyle.none
        
        return cell
    }
    
    // MARK: edit
    // Row Editable true
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    // Move Row Instance Method
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}


import UIKit
import SpriteKit
import GameplayKit
import AVFoundation
import FirebaseDatabase

class FriendGameScene: SKScene {
    var border = SKShapeNode()
//    weak var friendGameDelegate: FriendGameSceneDelegate!
    
    // Define physics categories
    struct PhysicsCategory {
        static let none: UInt32 = 0
        static let cat: UInt32 = 0b1
        static let furniture: UInt32 = 0b10
    }
    
    // 타일 이미지
    var wallTileTexture = SKTexture(imageNamed: "wall_01_01")
    var moldingTileTexture = SKTexture(imageNamed: "molding_01_01")
    var floorTileTexture = SKTexture(imageNamed: "wall_01_01")
    var windowTileTexture = SKTexture(imageNamed: "window_01_01")
    
    var catSprite = SKSpriteNode()
    var catSize = CGSize(width: 40, height: 40)
    var catTouchedSize = CGSize(width: 50, height: 50)
    
    var catNum: String = "01" {
        didSet {
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
    
    var bubbleSprite = SKSpriteNode()
    let bubbleSpriteList = ["bubble01", "bubble02", "bubble03", "bubble04", "bubble05", "bubble06", "bubble07", "bubble08", "bubble09"]
    
    var dirtySprite = SKSpriteNode()
    var dirtySpriteList = ["dirty01", "dirty02", "dirty03", "dirty04", "dirty05"]
    var dirtyCount: Int = 0
    var dirtySpriteData: [String: [String: Any]] = [:]
    var placedItems: PlacedItmes?
    
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
                
                _ = catSprite.position.x
                bubbleSprite.removeFromParent()
                
                bubbleSprite = SKSpriteNode(imageNamed: bubbleSpriteList[Int.random(in: 0...bubbleSpriteList.count-1)])
                bubbleSprite.size = CGSize(width: 100, height: 100)
                bubbleSprite.position = CGPoint(x: catSprite.position.x, y: catSprite.position.y)
                bubbleSprite.zPosition = 10
                addChild(bubbleSprite)
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                    self.bubbleSprite.size = CGSize(width: 0, height: 0)
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
        wallTileTexture = SKTexture(imageNamed: placedItems?.wall ?? "wall_01_01")
        moldingTileTexture = SKTexture(imageNamed: placedItems?.molding ?? "molding_01_01")
        floorTileTexture = SKTexture(imageNamed: placedItems?.floor ?? "floor_01_01")
        
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
        let windowSprite_1 = SKSpriteNode(imageNamed: placedItems?.window ?? "window_01_01")
        targetSize = CGSize(width: 60, height: 60)
        windowSprite_1.adjustAspectFill(to: targetSize)
        windowSprite_1.position = .relativePosition(x: 0.8, y: 0.8, in: frame)
        windowSprite_1.zPosition = -5
        addChild(windowSprite_1)
        
        let windowSprite_2 = SKSpriteNode(imageNamed: placedItems?.window ?? "window_01_01")
        targetSize = CGSize(width: 60, height: 60)
        windowSprite_2.adjustAspectFill(to: targetSize)
        windowSprite_2.position = .relativePosition(x: 0.2, y: 0.8, in: frame)
        windowSprite_2.zPosition = -5
        addChild(windowSprite_2)
        
        let rugSprite = SKSpriteNode(imageNamed: placedItems?.rug ?? "rug_01_01")
        targetSize = CGSize(width: 60, height: 60)
        rugSprite.adjustAspectFill(to: targetSize)
        rugSprite.position = .relativePosition(x: 0.8, y: 0.26, in: frame)
        rugSprite.zPosition = 0
        addChild(rugSprite)
        
        let lightningSprite_1 = SKSpriteNode(imageNamed: placedItems?.lightning ?? "lightning_01_01")
        targetSize = CGSize(width: 25, height: 25)
        lightningSprite_1.adjustAspectFill(to: targetSize)
        lightningSprite_1.zPosition = 3
        lightningSprite_1.physicsBody = SKPhysicsBody(rectangleOf: lightningSprite_1.size)
        lightningSprite_1.physicsBody?.categoryBitMask = PhysicsCategory.furniture
        lightningSprite_1.physicsBody?.collisionBitMask = PhysicsCategory.cat
        lightningSprite_1.physicsBody?.contactTestBitMask = PhysicsCategory.cat
        lightningSprite_1.physicsBody?.isDynamic = false
        
        let lightningSprite_2 = SKSpriteNode(imageNamed: placedItems?.lightning ?? "lightning_01_01")
        targetSize = CGSize(width: 25, height: 25)
        lightningSprite_2.adjustAspectFill(to: targetSize)
        lightningSprite_2.zPosition = 3
        lightningSprite_2.physicsBody = SKPhysicsBody(rectangleOf: lightningSprite_2.size)
        lightningSprite_2.physicsBody?.categoryBitMask = PhysicsCategory.furniture
        lightningSprite_2.physicsBody?.collisionBitMask = PhysicsCategory.cat
        lightningSprite_2.physicsBody?.contactTestBitMask = PhysicsCategory.cat
        lightningSprite_2.physicsBody?.isDynamic = false
        
        switch placedItems?.lightning.split(separator: "_")[1] {
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
        
        let plantSprite = SKSpriteNode(imageNamed: placedItems?.plant ?? "plant_01_01")
        targetSize = CGSize(width: 40, height: 40)
        plantSprite.adjustAspectFill(to: targetSize)
        plantSprite.position = .relativePosition(x: 0.2, y: 0.5, in: frame)
        plantSprite.zPosition = 2.5
        addChild(plantSprite)
        
        let sofaSprite = SKSpriteNode(imageNamed: placedItems?.sofa ?? "sofa_01_01")
        targetSize = CGSize(width: 70, height: 60)
        sofaSprite.adjustAspectFill(to: targetSize)
        sofaSprite.position = .relativePosition(x: 0.4, y: 0.5, in: frame)
        sofaSprite.zPosition = 3
        
//        sofaSprite.physicsBody = SKPhysicsBody(rectangleOf: sofaSprite.size)
//        sofaSprite.physicsBody?.categoryBitMask = PhysicsCategory.furniture
//        sofaSprite.physicsBody?.collisionBitMask = PhysicsCategory.cat
//        sofaSprite.physicsBody?.contactTestBitMask = PhysicsCategory.cat
//        sofaSprite.physicsBody?.isDynamic = false
        addChild(sofaSprite)
        
        let tableSprite = SKSpriteNode(imageNamed: placedItems?.table ?? "table_01_01")
        targetSize = CGSize(width: 50, height: 50)
        tableSprite.adjustAspectFill(to: targetSize)
        tableSprite.position = .relativePosition(x: 0.2, y: 0.2, in: frame)
        tableSprite.zPosition = 3
        
        let upperBodySize = CGSize(width: tableSprite.size.width, height: tableSprite.size.height / 1.3)
        let upperBodyOffset = CGPoint(x: 0, y: tableSprite.size.height / 6)
        
        tableSprite.physicsBody = SKPhysicsBody(rectangleOf: upperBodySize, center: upperBodyOffset)
        tableSprite.physicsBody?.categoryBitMask = PhysicsCategory.furniture
        tableSprite.physicsBody?.collisionBitMask = PhysicsCategory.cat
        tableSprite.physicsBody?.contactTestBitMask = PhysicsCategory.cat
        tableSprite.physicsBody?.isDynamic = false
        addChild(tableSprite)
        
        let chairSprite = SKSpriteNode(imageNamed: placedItems?.chair ?? "chair_01_01")
        targetSize = CGSize(width: 30, height: 30)
        chairSprite.adjustAspectFill(to: targetSize)
        chairSprite.position = .relativePosition(x: 0.35, y: 0.2, in: frame)
        chairSprite.zPosition = 3
        addChild(chairSprite)
        
        let catTowerSprite = SKSpriteNode(imageNamed: placedItems?.catTower ?? "catTower_01_01")
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
        catSprite = SKSpriteNode(imageNamed: self.sittingCatImage[0] as! String)
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
        for imageName in self.walkingCatImage {
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
        for imageName in self.idleCatImage {
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
        for imageName in self.lickingCatImage {
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
        for imageName in self.sittingCatImage {
            let texture = SKTexture(imageNamed: imageName as! String)
            sittingFrames.append(texture)
        }
        
        let sittingAnimation = SKAction.animate(with: sittingFrames, timePerFrame: 0.1)
        let repeatSittingAnimation = SKAction.repeatForever(sittingAnimation)
        catSprite.run(repeatSittingAnimation)
    }
}

extension FriendGameScene {
    func randomPosition() -> CGPoint {
        let padding: CGFloat = 20.0  // 경계선에서 일정 거리 떨어진 위치를 위한 패딩값 설정
        let xPosition = CGFloat.random(in: padding...(size.width - padding))
        let yPosition = CGFloat.random(in: padding...(size.height / 2 - padding))
        return CGPoint(x: xPosition, y: yPosition)
    }
}

extension FriendGameScene {
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
        
        let bubbleHeight = totalHeight * 7
        let bubbleWidth: CGFloat = 180 // Fixed width for bubble
        bubbleSprite.scaleToFill(to: CGSize(width: bubbleWidth, height: bubbleHeight))
        bubbleSprite.position = CGPoint(x: catSprite.position.x, y: catSprite.position.y + catSprite.size.height / 2 + bubbleHeight / 2)
        
        // Add labels to the bubble
        for (index, line) in lines.enumerated() {
            let labelNode = SKLabelNode(text: line)
            labelNode.fontName = "Arial"
            labelNode.fontSize = 10
            labelNode.fontColor = .black
            labelNode.horizontalAlignmentMode = .center
            labelNode.verticalAlignmentMode = .center
            labelNode.position = CGPoint(x: 0, y: bubbleHeight / 2 - CGFloat(index) * lineHeight - lineHeight / 2 - 3.2)
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
