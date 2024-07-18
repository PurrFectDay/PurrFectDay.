//
//  GoalViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/05/17.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase

class GoalViewController: UIViewController, UIGestureRecognizerDelegate {
    
    var window: UIWindow?
    
    var calendarTypeNumber: Int = 0
    var goalListArray: [[Any]] = [] {
        didSet {
            self.goalTableView.reloadData()
        }
    }
    var goalDictionary: [Int: [String: Any]] = [:] {
        didSet {
            print("didSet goalDictionary: \(self.goalDictionary)")
            
            let sortedKeys = self.goalDictionary.keys.sorted { $0 < $1 }
            self.goalListArray.removeAll()
            for key in sortedKeys {
                if let goal = self.goalDictionary[key] {
                    self.goalListArray.append([key, goal])
                }
            }
            print("didSet goalListArray: \(self.goalListArray)")
            
            self.goalTableView.reloadData()
        }
    }
    var todoListArray: [[[Any]]] = [[]] {
        didSet {
            // 데이터가 업데이트되었을 때 실행할 작업을 수행
            print("didSet todoListArray: \(self.todoListArray)")
        }
    }
    
    // 키보드
    private var frameHeight = 0.0
    private var navigationBarHeight = 0.0
    
    @IBOutlet weak var goalTableView: UITableView!
    
    @IBAction func goBack(_ sender: UIButton) {
//        self.navigationController?.popViewController(animated: true)
        
//        if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
//            // 현재 ViewController의 Storyboard ID를 명시적으로 설정합니다.
//            let storyboardID = "HomeView" // 여기서 "HomeViewController"는 설정한 Storyboard ID입니다.
//            
//            // 스토리보드에서 현재 ViewController를 새로 인스턴스화합니다.
//            let storyboard = UIStoryboard(name: "Main", bundle: nil)
//            if let newViewController = storyboard.instantiateViewController(withIdentifier: storyboardID) as? HomeViewController {
//                // 새 인스턴스를 rootViewController로 설정합니다.
//                sceneDelegate.window?.rootViewController = newViewController
//                sceneDelegate.window?.makeKeyAndVisible()
//            } else {
//                fatalError("Storyboard ID \(storyboardID)를 가진 ViewController를 찾을 수 없습니다.")
//            }
//        }
        
        if let navigationController = self.navigationController {
            let storyboardID = "HomeView"
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let newViewController = storyboard.instantiateViewController(withIdentifier: storyboardID) as? HomeViewController else {
                fatalError("Storyboard ID \(storyboardID)를 가진 ViewController를 찾을 수 없습니다.")
            }
            navigationController.setViewControllers([newViewController], animated: false)
        }
    }
    
    @IBAction func addGoal(_ sender: UIButton) {
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
    }
    
    // MARK: - viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        if (!BackgroundMusicPlayer.shared.player!.isPlaying || UserDefaults.standard.string(forKey: "BackgroundMusicName") != "Love Cat paw") {
            BackgroundMusicPlayer.shared.play(fileName: "Love Cat paw")
        }
        // 앱이 백그라운드로 전환될 때 배경음악 일시 중지하는 옵저버 추가
        NotificationCenter.default.addObserver(self, selector: #selector(pauseSong), name: UIApplication.didEnterBackgroundNotification, object: nil)
        // 앱이 포그라운드로 다시 들어올 때 배경음악 재생하는 옵저버 추가
        NotificationCenter.default.addObserver(self, selector: #selector(playSong), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        self.goalTableView.beginUpdates()
        DatabaseUtils.shared.getGoals() { goal in
            self.goalDictionary = goal
        }
        self.goalTableView.endUpdates()
    }
    
    // MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        goalTableView.delegate = self
        goalTableView.dataSource = self
        
        // 테이블 드래그 앤 드롭으로 row 이동하기
//        goalTableView.dragInteractionEnabled = true
//        goalTableView.dragDelegate = self
//        goalTableView.dropDelegate = self
        
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
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    // MARK: - viewWillDisappear
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    private func goals(for section: Int) -> [[Any]] {
        return goalDictionary
            .filter { (_, value) in
                if let ongoing = value["ongoing"] as? Bool {
                    return ongoing == (section == 1)
                }
                return false
            }
            .sorted { $0.key < $1.key }
            .map { [$0.key, $0.value] }
    }
    
    // MARK: - background music 관련
    deinit {
        // 옵저버 제거
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func pauseSong() {
        BackgroundMusicPlayer.shared.pause()
    }
    
    @objc func playSong() {
        BackgroundMusicPlayer.shared.player?.play()
    }
}

// MARK: - 테이블
extension GoalViewController: UITableViewDataSource, UITableViewDelegate {
    // MARK: - section
    // 섹션 수 반환
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    // 각 섹션의 행 수 반환
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return goals(for: section).count
    }
    
    // 섹션 헤더 설정
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "보관된 목표" : "진행 중인 목표"
    }
    
    // 섹션 헤더 높이 설정
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 44
    }
    
    // MARK: - cell
    // 특정 위치에 해당하는 테이블 뷰 셀을 반환
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "GoalListCell") as? GoalListCell else {
            fatalError("Failed to dequeue a GoalListCell.")
        }
        
        let goal = goals(for: indexPath.section)[indexPath.row]
        let databaseKey = goal[0] as! Int
        let goalData = goal[1] as! [String: Any]
        let goalTitle = goalData["title"] as? String
        let endDate = goalData["endDate"] as? String
        let ongoing = goalData["ongoing"] as? Bool ?? true
        
        cell.goalTextField.text = goalTitle
        cell.selectionStyle = .none
        cell.editIndexPath = indexPath
        cell.editDelegate = self
        
        // 목표가 완료된 상태일 때만 종료 날짜를 설정
        if !ongoing {
            cell.updateEndDateLabel(endDate: endDate)
        } else {
            cell.updateEndDateLabel(endDate: nil)
        }
        
        let edit = UIAction(title: "수정", image: UIImage(systemName: "square.and.pencil"), handler: { _ in
            AlertUtils.showTextFieldAlert(view: self, title: "목표 수정", message: "", placehold: goalTitle!, isPassword: false) { text in
                guard let text = text, !text.isEmpty else {
                    self.view.makeToast("수정할 내용을 입력해주세요.", duration: 3.0, position: .top)
                    return
                }
                DatabaseUtils.shared.updateGoalTitle(key: databaseKey, title: text) { goalData in
                    self.goalDictionary = goalData
                }
            }
        })
        let delete = UIAction(title: "삭제", image: UIImage(systemName: "trash.fill"), handler: { _ in
            AlertUtils.showYesNoAlert(view: self, title: "경고", message: "목표 안의 모든 할 일들이 삭제됩니다. 정말로 삭제하시겠습니까?") { yes in
                if yes {
                    DatabaseUtils.shared.removeGoal(key: databaseKey) { goalData, todoData in
                        self.goalDictionary = goalData
                        self.todoListArray = todoData
                    }
                }
            }
        })
        let store = UIAction(title: "보관", image: UIImage(systemName: "archivebox.fill"), handler: { _ in
            DatabaseUtils.shared.updateGoalState(date: self.getCurrentDate(), key: databaseKey, state: false) { goalData in
                self.goalDictionary = goalData
            }
        })
        let restore = UIAction(title: "복구", image: UIImage(systemName: "arrowshape.turn.up.backward.fill"), handler: { _ in
            DatabaseUtils.shared.updateGoalState(date: self.getCurrentDate(), key: databaseKey, state: true) { goalData in
                self.goalDictionary = goalData
            }
        })
        
        cell.ellipsisButton.menu = UIMenu(title: "목표", identifier: nil, options: .displayInline, children: indexPath.section == 0 ? [edit, delete, restore] : [edit, delete, store])
        
        return cell
    }
        
    // Helper method to get current date as a string
    func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: edit
    // Row Editable true
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // 테이블 뷰의 cellForRowAt 메서드에서 호출하는 부분
    // 셀 삭제
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let goal = goals(for: indexPath.section)[indexPath.row]
            let key = goal[0] as! Int
            
            // db와 table에서 삭제
            DatabaseUtils.shared.removeGoal(key: key) { goalData, todoData in
                self.goalDictionary = goalData
                self.todoListArray = todoData
            }
        }
    }
    
    // Move Row Instance Method
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let fromIndex = indexInAllGoals(from: sourceIndexPath)
        let toIndex = indexInAllGoals(from: destinationIndexPath)

//        guard fromIndex != -1, toIndex != -1,
//              let movedGoalKey = goalListArray[fromIndex][0] as? Int,
//              let targetGoalKey = goalListArray[toIndex][0] as? Int else {
//            print("Error: Invalid indices or data types")
//            return
//        }
        
        DatabaseUtils.shared.moveGoal(from: fromIndex, to: toIndex, completion: { data in
            self.goalDictionary = data
            self.goalTableView.reloadData()
        })
    }

    private func indexInAllGoals(from indexPath: IndexPath) -> Int {
//        let ongoingGoals = goals(for: 1)
        let storedGoals = goals(for: 0)
        
        if indexPath.section == 0 {
            return indexPath.row
        } else {
            return storedGoals.count + indexPath.row
        }
    }


    @objc func addNewRow(_ sender: UIButton) {
        let row = sender.tag
        
        // 아직 db에 추가되지는 않고 화면 상에만 표시되도록 함. 빈 내용이 아니면 delegate에서 db에 추가.
        self.goalListArray[row].append(["", false])
        
        // 각 cell의 todoTextField 텍스트의 내용을 각 todoListArray에 해당하는 "할 일" 내용으로 설정
        let lastRowIndex = self.goalListArray[row].count - 1
        let pathToLastRow = IndexPath.init(row: lastRowIndex, section: row)
        
        // 셀이 화면에 보이지 않을 경우 스크롤하여 화면에 보이게 함
        self.goalTableView.scrollToRow(at: pathToLastRow, at: .bottom, animated: true)
        
        if let cell = self.goalTableView.cellForRow(at: pathToLastRow) {
            // 셀 내의 서브뷰 중 UITextField 타입을 찾아 포커스 이동
            for subview in cell.contentView.subviews {
                if let textField = subview as? UITextField {
                    if (textField.isFocused == false) {
                        textField.becomeFirstResponder()
                    }
                }
            }
        }
    }
}

// MARK: TableView Cell
class GoalListCell: UITableViewCell {
    @IBOutlet weak var goalTextField: UITextField!
    @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var ellipsisButton: UIButton!
    
    var editDelegate: GoalEditedDelegate?
    var editIndexPath: IndexPath?
    var originText: String?
    
    @IBAction func beginEditingTodoTextField(_ sender: UITextField) {
        originText = goalTextField.text
    }
    
    @IBAction func endEditingTodoTextField(_ sender: UITextField) {
        editDelegate?.textFieldEdited(index: editIndexPath!, originText: originText!, editedText: goalTextField.text!)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func updateEndDateLabel(endDate: String?) {
        if let endDate = endDate, !endDate.isEmpty {
            endDateLabel.text = "종료일: \(endDate)"
            endDateLabel.isHidden = false
        } else {
            endDateLabel.isHidden = true
        }
    }
}


// MARK: - UITableView UITableViewDropDelegate, UITableViewDropDelegate
//extension GoalViewController: UITableViewDragDelegate {
//    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
//        return [UIDragItem(itemProvider: NSItemProvider())]
//    }
//}
//
//extension GoalViewController: UITableViewDropDelegate {
//    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
//        if session.localDragSession != nil {
//            return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
//        }
//        return UITableViewDropProposal(operation: .cancel, intent: .unspecified)
//    }
//    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) { }
//}


// MARK: GoalEditedDelegate, protocol
protocol GoalEditedDelegate {
    func textFieldEdited(index: IndexPath, originText: String, editedText: String)
}

extension GoalViewController: GoalEditedDelegate {
    func textFieldEdited(index: IndexPath, originText: String, editedText: String) {
        let goal = goals(for: index.section)[index.row]
        let key = goal[0] as! Int
        
        if originText.isEmpty && !editedText.isEmpty {
            DatabaseUtils.shared.addGoal(title: editedText) { goalData, todoData in
                self.goalDictionary = goalData
                self.todoListArray = todoData
            }
        } else if !originText.isEmpty && editedText.isEmpty {
            AlertUtils.showYesNoAlert(view: self, title: "경고", message: "내용이 비어 있어 해당 항목이 삭제됩니다.\n⚠️목표 삭제시, 그 안의 모든 할 일들이 삭제됩니다.") { yes in
                if yes {
                    DatabaseUtils.shared.removeGoal(key: key) { goalData, todoData in
                        self.goalDictionary = goalData
                        self.todoListArray = todoData
                    }
                } else {
                    self.goalTableView.reloadRows(at: [index], with: .automatic)
                }
            }
        } else if !originText.isEmpty && !editedText.isEmpty {
            DatabaseUtils.shared.updateGoalTitle(key: key, title: editedText) { goalData in
                self.goalDictionary = goalData
            }
        }
    }
}
