//
//  HomeViewControlloer.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/11.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import FSCalendar
import SpriteKit
import GameplayKit


class HomeViewController: UIViewController, UIGestureRecognizerDelegate {
    var handle: AuthStateDidChangeListenerHandle?
    var ref: DatabaseReference!
    let currentUserId = Auth.auth().currentUser!.uid
    
    var window: UIWindow?
    var scene: GameScene?
    
    @IBOutlet weak var gameView: SKView!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var pointButton: UIButton!
    
    @IBOutlet weak var progressButton: UIButton!
    var circleProgressView: CircleProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    
    @IBOutlet weak var calendarView: FSCalendar!
    @IBOutlet weak var calendarChangeButton: UIButton!
    @IBOutlet weak var todoTableView: UITableView!
    @IBOutlet weak var ellipsisButton: UIButton!
    
    private var point = 0 {
        didSet {
            print("didSet point: \(self.point)")
            self.pointButton.setTitle(String(self.point), for: .normal)
            self.pointButton?.invalidateIntrinsicContentSize()
        }
    }
    // 투두 리스트
    var calendarTypeNumber = 0
    // 한국 표준시(KST) 시간대를 설정
    let koreaTimeZone = TimeZone(identifier: "Asia/Seoul")!
    var d_date = Date() {
        didSet {
            // 데이터가 업데이트되었을 때 실행할 작업을 수행
            self.s_date = DatabaseUtils.shared.dateFormatter(date: self.d_date)
        }
    }
    var s_date = { let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: Date()) }()
    
    var eventsCountDict: [String: Int] = [:]
    
    var tableIndex: IndexPath?
    var databaseIndex: IndexPath?
    var goalListArray: [[Any]] = [] {
        didSet {
//            print("didSet goalListArray: \(self.goalListArray)")
        }
    }
    var goalDictionary: [Int: [String: Any]] = [:] {
        didSet {
//            let filteredGoals = goalDictionary.filter { key, goal in
//                if let endDate = goal["endDate"] as? String {
//                    return self.s_date <= endDate || goal["ongoing"] as? Bool ?? true
//                }
//                return true
//            }
            let sortedKeys = goalDictionary.keys.sorted { $0 < $1 }
            self.goalListArray.removeAll()
            for key in sortedKeys {
                if let goal = goalDictionary[key] {
                    self.goalListArray.append([key, goal])
                }
            }
            self.todoTableView.reloadData()
        }
    }


    var todoListArray: [[[Any]]] = [[]] {
        didSet {
            // 데이터가 업데이트되었을 때 실행할 작업을 수행
            print("didSet todoListArray: \(self.todoListArray)")
            self.todoTableView.reloadData()
        }
    }
    var isTodoCheck = false
    
    // 키보드
    private var frameHeight = 0.0
    private var navigationBarHeight = 0.0
    
    
    // MARK: - viewWillAppear
    // MARK: - viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        
        if navigationController?.topViewController === self && BackgroundMusicPlayer.shared.getInitialVolume() != 0.0 {
            if (!BackgroundMusicPlayer.shared.player!.isPlaying || UserDefaults.standard.string(forKey: "BackgroundMusicName") != "Love Cat paw") {
                BackgroundMusicPlayer.shared.play(fileName: "Love Cat paw")
            }
        }
        
        // 앱이 백그라운드로 전환될 때 배경음악 일시 중지하는 옵저버 추가
        NotificationCenter.default.addObserver(self, selector: #selector(pauseSong), name: UIApplication.didEnterBackgroundNotification, object: nil)
        // 앱이 포그라운드로 다시 들어올 때 배경음악 재생하는 옵저버 추가
        NotificationCenter.default.addObserver(self, selector: #selector(playSong), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        self.loadGoalsAndTodos(for: self.s_date)
        
        DatabaseUtils.shared.getPoint { pointData in
            self.point = pointData
        }
        
        // 게임 scene
        if let view = gameView {
            self.scene = GameScene(size: gameView.bounds.size)
            scene?.gameDelegate = self
            scene?.scaleMode = .aspectFill
            view.presentScene(scene)
            view.ignoresSiblingOrder = true
            view.layer.cornerRadius = 20
        }
        
        
        
        // 프로필 버튼
        let catNum = DatabaseUtils.shared.catNum
        let profileImage = "cat\(catNum)_sitting_01"
        
        // 1. 버튼의 배경색 설정 및 원형으로 만들기
        profileButton.backgroundColor = UIColor(named: "GrayGreen") // 원하는 배경색으로 설정
        profileButton.layer.cornerRadius = profileButton.bounds.size.width / 2
        profileButton.layer.masksToBounds = true

        // 2. UIButtonConfiguration 사용
        var config = UIButton.Configuration.plain()

        // 이미지를 버튼 높이에 맞추기 위해 크기 조정
        if let image = UIImage(named: profileImage) {
            let buttonHeight = profileButton.bounds.size.height
            let aspectRatio = image.size.width / image.size.height
            let resizedImage = UIGraphicsImageRenderer(size: CGSize(width: buttonHeight * aspectRatio, height: buttonHeight)).image { _ in
                image.draw(in: CGRect(origin: .zero, size: CGSize(width: buttonHeight * aspectRatio, height: buttonHeight)))
            }
            config.image = resizedImage
        }

        config.imagePlacement = .top
        config.contentInsets = .zero // 버튼의 내용에 대한 여백 제거
        
        // 3. UIButtonConfiguration 적용
        profileButton.configuration = config

        // 4. 이미지 중앙 정렬
        profileButton.contentHorizontalAlignment = .center
        profileButton.contentVerticalAlignment = .center
    }
    
    // MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // [START auth_listener] 리스너 연결
        handle = Auth.auth().addStateDidChangeListener { auth, user in
            // [START_EXCLUDE]
            // [END_EXCLUDE]
        }
        // Firebase Database Reference 초기화
        ref = Database.database().reference()
        
        
        let today = DatabaseUtils.shared.dateFormatter(date: Date())
        let userRef = ref.child("users/\(currentUserId)/friend/bubble/\(today)")
        userRef.observe(.value) { snapshot in
            print("DEBUG: snapshot key is \(snapshot.key)")
            
            DatabaseUtils.shared.getBubble(completion: { data in
                print(data)
                self.scene?.bubbleTextList = data
                self.scene?.makeBubbleSprite(with: data.last ?? "힘내!")
            })
        }
        
        // 진행도 버튼
        progressButton.layer.cornerRadius = 50
        progressButton.layer.cornerRadius = progressButton.bounds.size.width / 2
        
        circleProgressView = CircleProgressView(frame: progressButton.bounds)
        circleProgressView.backgroundColor = .clear // 배경을 투명하게 설정
        circleProgressView.backgroundCircleColor = UIColor(named: "GrayGreen")! // 배경 원의 색상 설정
        circleProgressView.progressColor = UIColor(named: "DeepGreen")!         // 진행 원의 색상 설정
        progressButton.addSubview(circleProgressView)
        circleProgressView.progress = 0.0
        
        let number = String(format: "%3d", 0)
        self.progressLabel.text = "\(number)%"
        
        // 테이블 뷰의 여백을 제거하기 위해 estimated heights를 0으로 설정
        todoTableView.estimatedSectionHeaderHeight = 0
        todoTableView.estimatedSectionFooterHeight = 0
        todoTableView.estimatedRowHeight = 0
        
        // 테이블 뷰의 여유 공간 설정
        let topInset: CGFloat = 0.0
        let bottomInset: CGFloat = 320.0
        
        todoTableView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
//        todoTableView.scrollIndicatorInsets = todoTableView.contentInset
        
        todoTableView.delegate = self
        todoTableView.dataSource = self
        
        // CustomHeaderFooterView를 등록
        todoTableView.register(UINib(nibName: "CustomHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "CustomHeaderView")
        
        // 테이블 드래그 앤 드롭으로 row 이동하기
        todoTableView.dragInteractionEnabled = true
        todoTableView.dragDelegate = self
        todoTableView.dropDelegate = self
        
        // 테이블뷰 모서리 둥글게
        todoTableView.layer.cornerRadius = 20
//        if #available(iOS 15, *) {
//            todoTableView.sectionHeaderTopPadding = 0 // 섹션 구분선 제거
//        }
        
        // 캘린더
        calendarUI()
        
        let add = UIAction(title: "목표 추가", image: UIImage(systemName: "folder.badge.plus"), handler: { _ in
            AlertUtils.showTextFieldAlert(view: self, title: "목표 추가", message: "", placehold: "추가할 목표의 내용을 입력해주세요." as String, isPassword: false) { text in
                if text == "" { // 수정 내용이 비어있음
                    self.view.makeToast("추가할 내용을 입력해주세요.", duration: 3.0, position: .top)
                }
                else if text == nil {
                    // Do nothing
                }
                else {
                    DatabaseUtils.shared.addGoal(title: text!) { goalData, todoData in
                        self.goalDictionary = goalData
                        self.todoListArray = todoData
                    }
                }
            }
            
        })
        let manage = UIAction(title: "목표 관리", image: UIImage(systemName: "folder.badge.gearshape"), handler: { _ in
            // Segue를 실행합니다.
            self.performSegue(withIdentifier: "HomeToGoalSegue", sender: self)
        })
        
        self.ellipsisButton.menu = UIMenu(
//            title: "타이틀",
//            image: UIImage(systemName: "heart"),
            identifier: nil,
            options: .displayInline,
            children: [add, manage])
        
        // 뷰의 초기 y 값을 저장해서 뷰가 올라갔는지 내려왔는지에 대한 분기처리시 사용.
        frameHeight = self.view.frame.origin.y
        if let navigationController = navigationController {
            let statusBarHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
            self.navigationBarHeight = statusBarHeight + navigationController.navigationBar.frame.height
        }
        
        // 네비게이션 바 색상 지정
//        navigationController!.navigationBar.backgroundColor = UIColor(named: "Cream")
//        if let scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance.copy() {
//            // 네비게이션 바의 배경색 설정
//            scrollEdgeAppearance.backgroundColor = UIColor(named: "Cream")
//            scrollEdgeAppearance.shadowColor = UIColor.clear
//            // 네비게이션 바 스크롤 엣지 설정
//            navigationController?.navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
//        }
        
        // 키보드 내리기
//        view.endEditing(true)
        // endEditing(_:) : cauese view to resign first responder
        let tapGesture = UITapGestureRecognizer(target: self.view, action: #selector(self.view.endEditing(_:)))
        self.view.addGestureRecognizer(tapGesture)
        
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        // FSCalendar의 제스처를 허용하도록 설정
        self.view.addGestureRecognizer(tapGesture)
        
        // UIResponder.keyboardWillShowNotification : 키보드가 해제되기 직전에 post 된다.
        NotificationCenter.default.addObserver(self, selector: #selector(showKeyboard(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        // UIResponder.keyboardWillHideNotificationdcdc : 키보드가 보여지기 직전에 post 된다.
        NotificationCenter.default.addObserver(self, selector: #selector(hideKeyboard(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: - viewWillDisappear
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: true)
        
        // [START remove_auth_listener] 리스너 분리
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
    }
    
    // MARK: - prepare
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "HomeToProfileSegue" {
            if let nextVC = segue.destination as? ProfileViewController {
                nextVC.preVC = "Home"
            }
        }
        
        if segue.identifier == "HomeToGoalSegue" {
            if segue.destination is GoalViewController {
                if let nextVC = segue.destination as? GoalViewController {
                    nextVC.calendarTypeNumber = self.calendarTypeNumber
                }
            }
        }
        
        if segue.identifier == "HomeToRoutineSegue" {
            if segue.destination is RoutineViewController {
                if let nextVC = segue.destination as? RoutineViewController {
                    nextVC.preVC = self
                    nextVC.tableIndex = self.tableIndex
                    nextVC.databaseIndex = self.databaseIndex
                }
            }
        }
    }
    
    // MARK: - background music 관련
    deinit {
        // 옵저버 제거
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 날짜에 따라 목표와 할 일 목록을 필터링하는 메서드 추가
    private func loadGoalsAndTodos(for date: String) {
        DatabaseUtils.shared.getGoals { goalData in
//            let filteredGoals = goalData.filter { key, goal in
//                if let endDate = goal["endDate"] as? String, !endDate.isEmpty {
//                    return date <= endDate || goal["ongoing"] as? Bool ?? true
//                }
//                return true
//            }
            self.goalDictionary = goalData
            if self.calendarTypeNumber == 2 {
//                self.goalDictionary = Dictionary(uniqueKeysWithValues: filteredGoals.filter { $0.value["ongoing"] as? Bool ?? true })
                DatabaseUtils.shared.getAllTodo { todoData in
                    self.todoListArray = todoData
                    self.updateProgressView() // 진행도 업데이트
                    
                    DispatchQueue.main.async {
                        self.todoTableView.beginUpdates()
                        self.todoTableView.endUpdates()
                    }
                }
            } else {
//                self.goalDictionary = Dictionary(uniqueKeysWithValues: filteredGoals.map { ($0.key, $0.value) })
                DatabaseUtils.shared.getTodoByDate(date: date) { todoData in
                    self.todoListArray = todoData
                    self.updateProgressView() // 진행도 업데이트
                    
                    DispatchQueue.main.async {
                        self.todoTableView.beginUpdates()
                        self.todoTableView.endUpdates()
                    }
                }
            }
        }
    }
    
    private func updateProgressView() {
        DatabaseUtils.shared.getProgress(completion: { data in
            let progress = data
            self.scene?.progress = progress
            
            if progress == 0 {
                self.animateProgress(to: 0)
            } else {
//                self.circleProgressView.progress = CGFloat(progress)
                self.animateProgress(to: CGFloat(progress) / 100)
            }
            
            self.progressLabel.text = "\(progress)%"
        })
    }

    private func animateProgress(to progress: CGFloat) {
        self.circleProgressView.setProgress(progress, animated: true)
    }
    
    // MARK: Calendar IBAction
    // 달력 보기 모드 바꾸기
    @IBAction func calendarChangeButton(_ sender: Any) {
        let calendarType = ["월", "주", "전체"]
        
        // 캘린더 타입 숫자가 0(월)인 경우 -> 1(주)로 변경
        switch calendarTypeNumber {
        case 0: // 월 -> 주
            self.calendarChangeButton.setTitle(calendarType[1], for: .normal)
            calendarTypeNumber = 1
            self.calendarView.frame.size.height = 110
            self.calendarView.scope = .week
            
            DatabaseUtils.shared.getTodoByDate(date: self.s_date) { todoData in
                self.todoListArray = todoData
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3, animations: {
                    }, completion: { _ in
                        self.todoTableView.performBatchUpdates({
                            self.todoTableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                            self.view.layoutIfNeeded()
                        }, completion: { _ in
                            self.todoTableView.setContentOffset(.zero, animated: true) // 테이블 뷰를 가장 위로 스크롤
                        })
                    })
                }
            }
        case 1: // 주 -> 전체
            self.calendarChangeButton.setTitle(calendarType[2], for: .normal)
            calendarTypeNumber = 2
            self.calendarView.frame.size.height = 0
            
            DatabaseUtils.shared.getAllTodo() { [weak self] todoData in
                guard let self = self else { return }
                self.todoListArray = todoData
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.calendarView.isHidden = true
                        
                    }, completion: { _ in
                        self.loadGoalsAndTodos(for: "")
                        self.todoTableView.performBatchUpdates({
                            self.todoTableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                            self.view.layoutIfNeeded()
                        }, completion: { _ in
                            self.todoTableView.setContentOffset(.zero, animated: true) // 테이블 뷰를 가장 위로 스크롤
                        })
                    })
                }
            }
        case 2: // 전체 -> 월
            self.calendarChangeButton.setTitle(calendarType[0], for: .normal)
            self.calendarView.frame.size.height = 280
            self.calendarView.scope = .month
            calendarTypeNumber = 0
            
            DatabaseUtils.shared.getTodoByDate(date: self.s_date) { [weak self] todoData in
                guard let self = self else { return }
                self.todoListArray = todoData
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.calendarView.isHidden = false
                        self.view.layoutIfNeeded()
                    }, completion: { _ in
                        self.todoTableView.performBatchUpdates({
                            self.todoTableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                        }, completion: { _ in
                            self.todoTableView.setContentOffset(.zero, animated: true) // 테이블 뷰를 가장 위로 스크롤
                        })
                    })
                }
            }
        default:
            break
        }
    }
}

// MARK: - 테이블
extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    // MARK: - section
    // 섹션 수 반환
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.goalListArray.isEmpty ? 1 : self.goalListArray.count
    }
    
    // 각 섹션의 행 수 반환
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
            
            if let date = goal["endDate"] as? String, !state {
                headerView.endDateLabel.isHidden = false
                headerView.updateEndDateLabel(endDate: date)
            } else {
                headerView.endDateLabel.isHidden = true
            }
        }
        
        headerView.calendarTypeNumber = self.calendarTypeNumber
        headerView.addTodoButton.tag = section  // 섹션 번호를 버튼의 태그로 설정
        headerView.addTodoButton.addTarget(self, action: #selector(addNewRow(_:)), for: .touchUpInside)
        
        return headerView
    }
    
    // 테이블 뷰의 헤더 뷰가 표시될 때 버튼의 상태를 설정하는 메서드 수정
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let headerView = view as? CustomHeaderView else { return }

        // 버튼의 intrinsicContentSize 재계산
        headerView.addTodoButton.invalidateIntrinsicContentSize()
        let edit = UIAction(title: "수정", image: UIImage(systemName: "square.and.pencil"), handler: { _ in
            AlertUtils.showTextFieldAlert(view: self, title: "목표 수정", message: "", placehold: headerView.addTodoButton.titleLabel!.text! as String, isPassword: false) { text in
                if text == "" { // 수정 내용이 비어있음
                    self.view.makeToast("수정할 내용을 입력해주세요.", duration: 3.0, position: .top)
                } else if text == nil {
                    // Do nothing
                } else {
                    let key = self.goalListArray[section][0] as! Int
                    DatabaseUtils.shared.updateGoalTitle(key: key, title: text!) { goalData in
                        self.goalDictionary = goalData
                    }
                }
            }
        })
        let delete = UIAction(title: "삭제", image: UIImage(systemName: "trash.fill"), handler: { _ in
            AlertUtils.showYesNoAlert(view: self, title: "경고", message: "목표 안의 모든 할 일들이 삭제됩니다. 정말로 삭제하시겠습니까?") { yes in
                if yes {
                    DatabaseUtils.shared.removeGoal(key: self.goalListArray[section][0] as! Int) { goalData, todoData in
                        self.goalDictionary = goalData
                        self.todoListArray = todoData
                        
//                        self.loadGoalsAndTodos(for: self.s_date)
//                        
//                        DatabaseUtils.shared.getNumberOfEvents(date: self.s_date) { data in
//                            self.eventsCountDict = [self.s_date: data]
//                            DispatchQueue.main.async {
//                                self.calendarView.reloadData() // 캘린더를 다시 로드하여 이벤트 수를 갱신
//                            }
//                        }
                    }
                }
            }
        })
        let store = UIAction(title: "보관", image: UIImage(systemName: "archivebox.fill"), handler: { _ in
            let key = self.goalListArray[section][0] as! Int
            let date = DatabaseUtils.shared.dateFormatter(date: Date())
            DatabaseUtils.shared.updateGoalState(date: date, key: key, state: false) { goalData in
                self.goalDictionary = goalData
                
//                if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
//                    // 현재 ViewController의 Storyboard ID를 명시적으로 설정합니다.
//                    let storyboardID = "HomeView" // 여기서 "HomeViewController"는 설정한 Storyboard ID입니다.
//                    
//                    // 스토리보드에서 현재 ViewController를 새로 인스턴스화합니다.
//                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
//                    if let newViewController = storyboard.instantiateViewController(withIdentifier: storyboardID) as? HomeViewController {
//                        // 새 인스턴스를 rootViewController로 설정합니다.
//                        sceneDelegate.window?.rootViewController = newViewController
//                        sceneDelegate.window?.makeKeyAndVisible()
//                    } else {
//                        fatalError("Storyboard ID \(storyboardID)를 가진 ViewController를 찾을 수 없습니다.")
//                    }
//                }

                if let navigationController = self.navigationController {
                    let storyboardID = "HomeView"
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    guard let newViewController = storyboard.instantiateViewController(withIdentifier: storyboardID) as? HomeViewController else {
                        fatalError("Storyboard ID \(storyboardID)를 가진 ViewController를 찾을 수 없습니다.")
                    }
                    navigationController.setViewControllers([newViewController], animated: false) 
                }
            }
        })
        let routine = UIAction(title: "루틴 추가", image: UIImage(systemName: "repeat"), handler: { [self] _ in
            let row = self.todoListArray[section].count
            self.tableIndex = IndexPath(row: row, section: section)
            
            var databaseIndex: IndexPath?
            switch calendarTypeNumber {
            case 2:
                let databaseSection = self.goalListArray[section][0] as! Int
                var databaseRow: Int?
                for section in self.todoListArray {
                    for row in section {
                        if row[3] as! Int == databaseSection {
                            databaseRow = row[4] as? Int
                        }
                    }
                }
                
                databaseIndex = IndexPath(row: databaseRow ?? 0, section: databaseSection)
            default:
                let databaseSection = self.goalListArray[section][0] as! Int
                databaseIndex = IndexPath(row: row, section: databaseSection)
            }
            self.databaseIndex = databaseIndex
            
            self.performSegue(withIdentifier: "HomeToRoutineSegue", sender: self)
            self.todoTableView.reloadSections(IndexSet(integer: section), with: .automatic)
            self.calendarView.reloadData()
            
        })
        
        let key = self.goalListArray[section][0] as! Int
        if let goal = self.goalDictionary[key], let state = goal["ongoing"] as? Bool {
            if state {
                headerView.ellipsisButton.menu = UIMenu(title: "진행 중인 목표",
                                         identifier: nil,
                                         options: .displayInline,
                                         children: [edit, delete, store, routine])
            } else {
                let restore = UIAction(title: "복구", image: UIImage(systemName: "arrowshape.turn.up.backward.fill"), handler: { _ in
                    let key = self.goalListArray[section][0] as! Int
                    DatabaseUtils.shared.updateGoalState(date: "", key: key, state: true) { goalData in
                        self.goalDictionary = goalData
                        
//                        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
//                            // 현재 ViewController의 Storyboard ID를 명시적으로 설정합니다.
//                            let storyboardID = "HomeView" // 여기서 "HomeViewController"는 설정한 Storyboard ID입니다.
//                            
//                            // 스토리보드에서 현재 ViewController를 새로 인스턴스화합니다.
//                            let storyboard = UIStoryboard(name: "Main", bundle: nil)
//                            if let newViewController = storyboard.instantiateViewController(withIdentifier: storyboardID) as? HomeViewController {
//                                // 새 인스턴스를 rootViewController로 설정합니다.
//                                sceneDelegate.window?.rootViewController = newViewController
//                                sceneDelegate.window?.makeKeyAndVisible()
//                            } else {
//                                fatalError("Storyboard ID \(storyboardID)를 가진 ViewController를 찾을 수 없습니다.")
//                            }
//                        }

                        
                        if let navigationController = self.navigationController {
                            let storyboardID = "HomeView"
                            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                            guard let newViewController = storyboard.instantiateViewController(withIdentifier: storyboardID) as? HomeViewController else {
                                fatalError("Storyboard ID \(storyboardID)를 가진 ViewController를 찾을 수 없습니다.")
                            }
                            navigationController.setViewControllers([newViewController], animated: false)
                        }
                    }
                })

                headerView.ellipsisButton.menu = UIMenu(title: "보관 중인 목표",
                                         identifier: nil,
                                         options: .displayInline,
                                         children: [edit, delete, restore])
            }
        }
    }
    
    func isTodayBefore(date: String) -> Bool {
        let targetString: String = date
        let fromString: String = DatabaseUtils.shared.dateFormatter(date: self.calendarView.selectedDate ?? Date())
        let dateFormatter: DateFormatter = .init()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let targetDate: Date = dateFormatter.date(from: targetString),
           let fromDate: Date = dateFormatter.date(from: fromString) {
            switch targetDate.compare(fromDate) {
            case .orderedSame: // 동일한 날짜
                return true
            case .orderedDescending: // from보다 이전
                return true
            case .orderedAscending: // from보다 이후
                return false
            }
        }
        
        return false
    }
    
    func shouldHideSection(section: Int) -> Bool {
        if !self.goalDictionary.isEmpty {
            let key = self.goalListArray[section][0] as! Int
            if let goal = self.goalDictionary[key], let state = goal["ongoing"] as? Bool, !state {  // ongoing이 false
                if calendarTypeNumber != 2 { // 전체 모드가 아닐 때
                    
                    if let endDate = goal["endDate"] as? String {
                        if section < todoListArray.count && todoListArray[section].isEmpty { // 해당 섹션의 할 일의 개수가 0개일 때
                            return true // 헤더 표시 안 함
                        }
                        
                        return !isTodayBefore(date: endDate)
                        
                    }
                } else { // 전체 모드인 경우, ongoing이 false인 목표는 숨김
                    return true
                }
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
        return shouldHideSection(section: indexPath.section) ? 0 : 44
    }
    
    // 섹션에 새로운 row 항목 추가하는 함수
    func addNewTodoItemToSection(_ section: Int) {
        let newTodoItem = ["", false] as [Any]  // 새로운 할 일 아이템 생성
        todoListArray[section].append(newTodoItem)  // 해당 섹션에 아이템 추가
    }
    
    // MARK: - cell
    // 특정 위치에 해당하는 테이블 뷰 셀을 반환
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 재사용 가능한 셀을 가져옴
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ToDoListCell") as? ToDoListCell else {
            fatalError("Failed to dequeue a ToDoListCell.")
        }
        
        cell.dateButton.invalidateIntrinsicContentSize()
        
        if calendarTypeNumber == 2 {
            cell.dateButton.isHidden = false
            cell.dateButton.isEnabled = true
            cell.dateButton.setTitle(self.todoListArray[indexPath.section][indexPath.row][2] as? String, for: .normal)
        }
        else {
            cell.dateButton.isHidden = true
            cell.dateButton.isEnabled = false
            cell.dateButton.setTitle("", for: .normal)
        }
        
        // 각 cell의 todoTextField 텍스트의 내용을 각 todoListArray에 해당하는 "할 일" 내용으로 설정
        if let todoTitle = self.todoListArray[indexPath.section][indexPath.row][0] as? String {
            cell.todoTextField.text = todoTitle
        } else {
            cell.todoTextField.text = ""
        }
        
        // 각 cell의 todoCheckButton을 각 todoListArray에 해당하는 Bool 타입에 따라 설정
        isTodoCheck = self.todoListArray[indexPath.section][indexPath.row][1] as! Bool
        
        if isTodoCheck == true {
            cell.todoCheckButton.setImage(UIImage(systemName: "square.inset.filled"), for: .normal)
        }
        else {
            cell.todoCheckButton.setImage(UIImage(systemName: "square"), for: .normal)
        }
        
        let key = self.goalListArray[indexPath.section][0] as! Int
        if let goal = self.goalDictionary[key], let state = goal["ongoing"] as? Bool {
            cell.updateInteractionState(isOngoing: state)
        }
        
        cell.selectionStyle = UITableViewCell.SelectionStyle.none
        cell.checkIndexPath = indexPath
        cell.checkDelegate = self
        cell.editIndexPath = indexPath
        cell.editDelegate = self
        cell.dateDelegate = self
        
        return cell
    }
    
    // MARK: edit
    // Row Editable true
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if calendarTypeNumber == 2 {
            return false
        }
        
        let key = self.goalListArray[indexPath.section][0] as! Int
        if let goal = self.goalDictionary[key], let state = goal["ongoing"] as? Bool {
            return state
        }
        return true
    }
    
    // 테이블 뷰의 cellForRowAt 메서드에서 호출하는 부분
    // 셀 삭제
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        var date: String
        let section = indexPath.section
        let row = indexPath.row
        var databaseIndex: IndexPath
        
        // 스와이프 시 삭제
        if editingStyle == .delete {
            switch calendarTypeNumber {
            case 2:
                let databaseSection = self.todoListArray[section][row][3] as! Int
                let databaseRow = self.todoListArray[section][row][4] as! Int
                databaseIndex = IndexPath(row: databaseRow, section: databaseSection)
                date = self.todoListArray[section][row][2] as! String
                
                // db와 table에서 삭제
                DatabaseUtils.shared.removeTodoAtAll(date: date, index: indexPath, databaseIndex: databaseIndex) { todoData in
                    self.todoListArray = todoData
                    
                    self.updateCalendarEvents(for: date)
                }
                
            default:
                let databaseSection = self.goalListArray[section][0] as! Int
                databaseIndex = IndexPath(row: row, section: databaseSection)
                date = self.s_date
                
                // db와 table에서 삭제
                DatabaseUtils.shared.removeTodo(date: date, index: indexPath, databaseIndex: databaseIndex) { todoData in
                    self.todoListArray = todoData
                    
                    self.updateCalendarEvents(for: date)
                }
            }
        }
    }
    
    // Move Row Instance Method
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        if calendarTypeNumber == 2 {
            return false
        }
        
        let key = self.goalListArray[indexPath.section][0] as! Int
        if let goal = self.goalDictionary[key], let state = goal["ongoing"] as? Bool {
            return state
        }
        
        return calendarTypeNumber != 2
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let fromSection = sourceIndexPath.section, fromRow = sourceIndexPath.row
        let toSection = destinationIndexPath.section, toRow = destinationIndexPath.row
        let fromDatabaseSection = self.goalListArray[fromSection][0] as! Int
        let toDatabaseSection = self.goalListArray[toSection][0] as! Int
        let fromDatabaseIndexPath = IndexPath(row: fromRow, section: fromDatabaseSection)
        let toDatabaseIndexPath = IndexPath(row: toRow, section: toDatabaseSection)
        
        DatabaseUtils.shared.moveTodo(date: self.s_date, from: sourceIndexPath, to: destinationIndexPath, fromDatabase: fromDatabaseIndexPath, toDatabase: toDatabaseIndexPath) { todoData in
            self.todoListArray = todoData
        }
    }
    
    @objc func addNewRow(_ sender: UIButton) {
        let section = sender.tag
        
        if calendarTypeNumber != 2 {
            // 아직 db에 추가되지는 않고 화면 상에만 표시되도록 함. 빈 내용이 아니면 delegate에서 db에 추가.
            if self.todoListArray.count < section {
                self.todoListArray.append([])
            }
            print(self.todoListArray)
            self.todoListArray[section].append(["", false])
            
            // 각 cell의 todoTextField 텍스트의 내용을 각 todoListArray에 해당하는 "할 일" 내용으로 설정
            let lastRowIndex = self.todoListArray[section].count - 1
            let pathToLastRow = IndexPath.init(row: lastRowIndex, section: section)
            
            // 셀이 화면에 보이지 않을 경우 스크롤하여 화면에 보이게 함
            self.todoTableView.scrollToRow(at: pathToLastRow, at: .bottom, animated: true)
            
            if let cell = self.todoTableView.cellForRow(at: pathToLastRow) {
                // 셀 내의 서브뷰 중 UITextField 타입을 찾아 포커스 이동
                for subview in cell.contentView.subviews {
                    if let textField = subview as? UITextField {
                        if (textField.isFocused == false) {
                            textField.becomeFirstResponder()
                        }
                    }
                }
            }
            
            // 셀이 화면에 보이지 않을 경우 스크롤하여 화면에 보이게 함
            let indexPath = IndexPath(row: self.todoListArray[section].count - 1, section: section)
            self.todoTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
        else {
            // 새 창에서 날짜 설정하고 추가
        }
    }
}

// MARK: TableHeaderView
class CustomHeaderView: UITableViewHeaderFooterView {
    @IBOutlet weak var addTodoButton: UIButton!
    @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var ellipsisButton: UIButton!
    
    var calendarTypeNumber: Int?
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // 버튼의 속성 초기화
        addTodoButton.titleLabel?.numberOfLines = 1
        addTodoButton.titleLabel?.lineBreakMode = .byTruncatingTail
    }
    
    // 버튼의 내용을 업데이트하는 메서드
    func updateButton(title: String, isOngoing: Bool) {
        addTodoButton.setTitle(title, for: .normal)
        addTodoButton.invalidateIntrinsicContentSize() // intrinsicContentSize 재계산
        
        addTodoButton.setBackgroundImage(nil, for: .normal)
        
        // 이미지의 크기 조절을 위해 이미지 인셋 설정
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .light)
        
        if calendarTypeNumber != 2 {
            // 목표의 상태에 따라 버튼 색상 변경
            if isOngoing {
                addTodoButton.backgroundColor = UIColor(named: "OliveGreen") // ongoing 상태일 때의 색상
                addTodoButton.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: imageConfig), for: .normal)
                
            } else {
                addTodoButton.backgroundColor = UIColor(named: "GrayGreen") // 완료된 목표일 때의 색상
                addTodoButton.setImage(UIImage(systemName: "archivebox.fill", withConfiguration: imageConfig), for: .normal)
            }
            addTodoButton.layer.cornerRadius = 10
        }
        else if calendarTypeNumber == 2 {
            addTodoButton.backgroundColor = .clear
            addTodoButton.setTitleColor(UIColor(named: "OliveGreen"), for: .normal)
        }
    }
    
    // 버튼 활성화/비활성화 상태 업데이트 메서드
    func updateButtonsEnabledState(isOngoing: Bool) {
        addTodoButton.isEnabled = isOngoing
    }
    
    func updateEndDateLabel(endDate: String) {
        if endDate != "" {
            endDateLabel.text = "종료일: \(endDate)"
        }
    }
}

// MARK: TableView Cell
class ToDoListCell: UITableViewCell {
    @IBOutlet weak var todoCheckButton: UIButton!
    @IBOutlet weak var todoTextField: UITextField!
    @IBOutlet weak var dateButton: UIButton!
    
    var checkDelegate: CheckButtonTappedDelegate?
    var checkIndexPath: IndexPath?
    var editDelegate: TextFieldEditedDelegate?
    var editIndexPath: IndexPath?
    var originText: String?
    
    var dateDelegate: DateButtonTappedDelegate?
    
    // 체크 버튼 선택 시 체크 기능 토글
    @IBAction func todoCheckButton(_ sender: Any) {
        checkDelegate?.checkButtonTapped(index: checkIndexPath!)
    }
    
    @IBAction func beginEditingTodoTextField(_ sender: UITextField) {
        originText = todoTextField.text
    }
    
    @IBAction func endEditingTodoTextField(_ sender: UITextField) {
        editDelegate?.textFieldEdited(index: editIndexPath!, originText: originText!, editedText: todoTextField.text!)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func updateInteractionState(isOngoing: Bool) {
        todoTextField.isEnabled = isOngoing
        todoCheckButton.isEnabled = isOngoing
    }
    
    @IBAction func dateButtonTapped(_ sender: UIButton) {
        dateDelegate?.dateButtonTapped(index: checkIndexPath!)
    }
    
}


// MARK: - UITableView UITableViewDropDelegate, UITableViewDropDelegate
extension HomeViewController: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if calendarTypeNumber == 2 {
            return [] // Dragging is disabled when calendarTypeNumber is 2
        }
        
        let key = self.goalListArray[indexPath.section][0] as! Int
        if let goal = self.goalDictionary[key], let state = goal["ongoing"] as? Bool, state {
            let itemProvider = NSItemProvider(object: self.todoListArray[indexPath.section][indexPath.row][0] as! NSString)
            return [UIDragItem(itemProvider: itemProvider)]
        }
        return []
    }
}

extension HomeViewController: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        if calendarTypeNumber == 2 {
            return UITableViewDropProposal(operation: .cancel) // Dropping is disabled when calendarTypeNumber is 2
        }
        
        if session.localDragSession != nil {
            let key = self.goalListArray[destinationIndexPath?.section ?? 0][0] as! Int
            if let goal = self.goalDictionary[key], let state = goal["ongoing"] as? Bool, state {
                return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            }
        }
        return UITableViewDropProposal(operation: .cancel, intent: .unspecified)
    }
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        // Handle drop if necessary
    }
}

// MARK: CheckButtonTappedDelegate, TextFieldEditedDelegate
protocol CheckButtonTappedDelegate {
    func checkButtonTapped(index: IndexPath)
}

protocol TextFieldEditedDelegate {
    func textFieldEdited(index: IndexPath, originText: String, editedText: String)
}

extension HomeViewController: CheckButtonTappedDelegate, TextFieldEditedDelegate {
    func checkButtonTapped(index: IndexPath) {
        let section = index.section
        let row = index.row
        let isTodoCheck = todoListArray[section][row][1] as! Bool
        
        if calendarTypeNumber == 2 {
            let databaseIndexPath = IndexPath(row: self.todoListArray[section][row][4] as! Int, section: self.todoListArray[section][row][3] as! Int)
            let date = self.todoListArray[section][row][2] as! String
            DatabaseUtils.shared.updateTodoCheck(date: date, index: index, databaseIndex: databaseIndexPath, todoStatus: !isTodoCheck) { todoData, pointData in
                self.todoListArray = todoData
                self.point = pointData
                self.updateProgressView() // 진행도 업데이트 및 애니메이션
                
                DatabaseUtils.shared.getNumberOfEvents(date: date) { data in
                    self.eventsCountDict = [date: data]
                    DispatchQueue.main.async {
                        self.calendarView.reloadData() // 캘린더를 다시 로드하여 이벤트 수를 갱신
                    }
                }
                
                if !isTodoCheck {
                    self.showBubbleSprite()
                }
            }
        } else {
            let databaseSection = self.goalListArray[section][0] as! Int
            let databaseIndexPath = IndexPath(row: row, section: databaseSection)
            
            let defaults = UserDefaults.standard
            let today = self.s_date
            
            DatabaseUtils.shared.updateTodoCheck(date: self.s_date, index: index, databaseIndex: databaseIndexPath, todoStatus: !isTodoCheck) { todoData, pointData in
                self.todoListArray = todoData
                
                if pointData >= 0 {
                    self.point = pointData
                } else if pointData == -1 {
                    let defaults = UserDefaults.standard
                    let today = DatabaseUtils.shared.dateFormatter(date: Date())

                    if !defaults.bool(forKey: "ShownMessageForMaxPoints\(today)") {
                        self.view.makeToast("대단해요!👏👏 하루에 얻을 수 있는 최대 포인트에 도달했습니다.\n모든 할 일을 완료하면 추가 포인트를 얻을 수 있으니 멈추지 말고 계속 해봐요!🏃", duration: 3.0, position: .center)
                        defaults.set(true, forKey: "ShownMessageForMaxPoints\(today)")
                    }
                } else if pointData == -2 {
                    if !defaults.bool(forKey: "ShownMessageForTotalMaxPoints\(today)") {
                        self.view.makeToast("놀라운 업적이에요!😲 얻을 수 있는 최대 포인트에 도달했습니다.", duration: 3.0, position: .center)
                        defaults.set(true, forKey: "ShownMessageForTotalMaxPoints\(today)")
                    }
                }
                
                self.updateProgressView() // 진행도 업데이트 및 애니메이션

                DatabaseUtils.shared.getNumberOfEvents(date: self.s_date) { data in
                    self.eventsCountDict = [self.s_date: data]
                    DispatchQueue.main.async {
                        self.calendarView.reloadData() // 캘린더를 다시 로드하여 이벤트 수를 갱신
                    }
                }
                
                if !isTodoCheck {
                    self.showBubbleSprite()
                }
            }
        }
    }
    
    func textFieldEdited(index: IndexPath, originText: String, editedText: String) {
        let section = index.section
        let row = index.row
        var databaseIndex: IndexPath
        var date: String
        
        switch calendarTypeNumber {
        case 2:
            let databaseSection = self.todoListArray[section][row][3] as! Int
            let databaseRow = self.todoListArray[section][row][4] as! Int
            databaseIndex = IndexPath(row: databaseRow, section: databaseSection)
            date = self.todoListArray[section][row][2] as! String
        default:
            let databaseSection = self.goalListArray[section][0] as! Int
            databaseIndex = IndexPath(row: row, section: databaseSection)
            date = self.s_date
        }
        
        if originText != "" && editedText == "" { // 기존 항목을 편집했는데, 내용이 비어 있음
            AlertUtils.showYesNoAlert(view: self, title: "경고", message: "내용이 비어 있어 해당 항목이 삭제됩니다.") { yes in
                if yes { // 확인
                    DatabaseUtils.shared.removeTodo(date: date, index: index, databaseIndex: databaseIndex) { todoData in
                        self.todoListArray = todoData
                        self.updateProgressView() // 진행도 업데이트 및 애니메이션
                    }
                } else { // 원래 내용으로 되돌림
                    self.todoListArray[section][row][0] = originText
                }
            }
        } else if originText == "" && editedText == "" { // 새로운 항목을 추가했는데, 내용이 비어있음 -> 추가하지 않음
            self.todoListArray[section].remove(at: row) // 아직 db에 추가되지 않은 상태이므로 로컬에서만 제거
        } else if originText != "" && editedText != "" { // 기존 항목을 수정함
            DatabaseUtils.shared.updateTodoContent(date: date, index: index, databaseIndex: databaseIndex, todoTitle: editedText) { todoData in
                self.todoListArray = todoData
                self.updateProgressView() // 진행도 업데이트 및 애니메이션

                DatabaseUtils.shared.getNumberOfEvents(date: date) { data in
                    self.eventsCountDict = [date: data]
                    DispatchQueue.main.async {
                        self.calendarView.reloadData() // 캘린더를 다시 로드하여 이벤트 수를 갱신
                    }
                }
            }
        } else if originText == "" && editedText != "" { // 새로운 항목을 추가함
            DatabaseUtils.shared.addTodo(date: date, index: index, databaseIndex: databaseIndex, todoTitle: editedText, todoStatus: false) { todoData in
                self.todoListArray = todoData
                self.updateProgressView() // 진행도 업데이트 및 애니메이션

                DatabaseUtils.shared.getNumberOfEvents(date: date) { data in
                    self.eventsCountDict = [date: data]
                    DispatchQueue.main.async {
                        self.calendarView.reloadData() // 캘린더를 다시 로드하여 이벤트 수를 갱신
                    }
                }
            }
        }
    }
}

protocol DateButtonTappedDelegate {
    func dateButtonTapped(index: IndexPath)
}

extension HomeViewController: DateButtonTappedDelegate {
    func dateButtonTapped(index: IndexPath) {
        if calendarTypeNumber == 2 {
            calendarTypeNumber = 0
            calendarView.isHidden = false
            calendarView.scope = .month
            calendarView.frame.size.height = 280
            
            let dateString = todoListArray[index.section][index.row][2] as! String
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: dateString) {
                calendarView.select(date, scrollToDate: true)
                self.d_date = date
                self.s_date = dateString
                self.loadGoalsAndTodos(for: dateString)
            }
        }
    }
}

extension HomeViewController: GameSceneDelegate {
    func updatePoints(_ points: Int) {
        if points >= 0 {
            self.point = points
        }
    }
    
    func showToast(message: String) {
        AlertUtils.showOkAlert(view: self, title: "경고", message: message) { _ in }
    }
    
    func showBubbleSprite() {
        self.scene?.showBubbleSprite()
    }
}


// MARK: - 캘린더
extension HomeViewController: FSCalendarDelegate, FSCalendarDataSource {
    // 캘린더 UI 설정
    func calendarUI() {
        calendarView.delegate = self
        calendarView.dataSource = self
        
        // 오늘 날짜를 선택하기
        self.d_date = Date()
        self.s_date = DatabaseUtils.shared.dateFormatter(date: Date())
        calendarView.select(self.d_date, scrollToDate: true)
        
        calendarView.appearance.headerDateFormat = "yyyy년 MM월"
//        calendarView.appearance.headerTitleColor = UIColor(named: "DeepGreen")
//        calendarView.appearance.weekdayTextColor = UIColor(named: "DeepGreen")
//        calendarView.appearance.titleDefaultColor = .darkGray
//        calendarView.appearance.titleWeekendColor = .darkGray
//        calendarView.appearance.todayColor = UIColor(named: "OliveGreen")
//        calendarView.appearance.selectionColor = UIColor(named: "DeepGreen")
        
        calendarView.appearance.eventDefaultColor = UIColor(named: "DeepGreen")
        calendarView.appearance.eventSelectionColor = UIColor(named: "GrayGreen")
        calendarView.appearance.headerMinimumDissolvedAlpha = 0.0
        
        calendarView.scope = .month
        calendarView.locale = Locale(identifier: "ko_KR")
        calendarView.firstWeekday = 2
    }
    
    // 날짜 변경
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        self.d_date = date
        self.s_date = DatabaseUtils.shared.dateFormatter(date: self.d_date)
        
        self.loadGoalsAndTodos(for: self.s_date)
//        DatabaseUtils.shared.getTodoByDate(date: self.s_date) { todoData in
//            print("todoData \(todoData)")
//            self.todoListArray = todoData
//        }
    }
    
    // 날짜에 표시할 이벤트 수
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let date = DatabaseUtils.shared.dateFormatter(date: date)
                
        // 저장된 이벤트 수가 있는지 확인
        if let count = eventsCountDict[date] {
            return count
        } else {
            DatabaseUtils.shared.getNumberOfEvents(date: date) { data in
                self.eventsCountDict[date] = Int(data)
                DispatchQueue.main.async {
                    calendar.reloadData() // 캘린더를 다시 로드하여 이벤트 수를 갱신
                }
            }
        }
        return 0
    }
}

// MARK: notification
extension HomeViewController {
    func updateCalendarEvents(for date: String) {
        DatabaseUtils.shared.getNumberOfEvents(date: date) { data in
            self.eventsCountDict[date] = Int(data)
            DispatchQueue.main.async {
                self.calendarView.reloadData() // 캘린더를 다시 로드하여 이벤트 수를 갱신
            }
        }
    }
    
    // MARK: - 키보드 관련 작업
    // 키보드 업
    @objc
    func showKeyboard(_ notification: Notification) {
        // 키보드가 내려왔을 때만 올린다.
        if self.view.frame.origin.y == frameHeight {
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                let keyboardHeight = keyboardFrame.cgRectValue.height
                self.view.frame.origin.y = self.frameHeight - keyboardHeight
//                self.view.frame.origin.y -= (keyboardHeight + self.navigationBarHeight)
                print("show keyboard")
            }
        }
        
        // 네비게이션 바 숨기기
//        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }

    // 키보드 다운
    @objc
    private func hideKeyboard(_ notification: Notification) {
        // 키보드가 올라갔을 때만 내린다.
        if self.view.frame.origin.y != frameHeight {
            if notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] is NSValue {
//                let keyboardHeight = keyboardFrame.cgRectValue.height
                self.view.frame.origin.y = self.frameHeight
                print("hide keyboard")
            }
        }
        
        // 네비게이션 바 나타내기
//        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    @objc func pauseSong() {
        BackgroundMusicPlayer.shared.pause()
    }
    
    @objc func playSong() {
        BackgroundMusicPlayer.shared.player?.play()
    }
}

class CircleProgressView: UIView {
    
    var progress: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var progressColor: UIColor = .blue {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var backgroundCircleColor: UIColor = .lightGray {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private var progressLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.clear(rect)
        
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let radius = min(bounds.width, bounds.height) / 2 - 5
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi * progress
        
        // Draw background circle
        let backgroundPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        backgroundCircleColor.setStroke()
        backgroundPath.lineWidth = 5
        backgroundPath.lineCapStyle = .round // 둥근 끝 부분 설정
        backgroundPath.stroke()
        
        // Draw progress circle
        let progressPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressColor.setStroke()
        progressPath.lineWidth = 5
        progressPath.lineCapStyle = .round // 둥근 끝 부분 설정
        progressPath.stroke()
    }
    
    // New method to animate progress changes
    func setProgress(_ newProgress: CGFloat, animated: Bool, duration: TimeInterval = 0.5) {
        if animated {
            let startProgress = self.progress
            let animationDuration = duration
            let animationStartDate = Date()
            
            Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
                let now = Date()
                let elapsedTime = now.timeIntervalSince(animationStartDate)
                if elapsedTime >= animationDuration {
                    self.progress = newProgress
                    timer.invalidate()
                } else {
                    let percentage = CGFloat(elapsedTime / animationDuration)
                    self.progress = startProgress + percentage * (newProgress - startProgress)
                }
            }
        } else {
            self.progress = newProgress
        }
    }
}

extension UserDefaults {
    private enum Keys {
        static let lastConnectionDate = "lastConnectionDate"
    }

    /// Save the current date as the last connection date
    func saveCurrentDateAsLastConnection() {
        let today = Date()
        set(today, forKey: Keys.lastConnectionDate)
    }

    /// Check if the user has connected today
    func hasConnectedToday() -> Bool {
        guard let lastConnectionDate = object(forKey: Keys.lastConnectionDate) as? Date else {
            // No record of previous connection, assume this is the first connection
            saveCurrentDateAsLastConnection()
            return false
        }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(lastConnectionDate) {
            // The saved date is today
            return true
        } else {
            // The saved date is not today, update to today
            saveCurrentDateAsLastConnection()
            return false
        }
    }
}
