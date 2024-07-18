//
//  RoutineViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/06/06.
//

import UIKit
import FSCalendar

class RoutineViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBAction func goBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
        
//        if let navigationController = self.navigationController {
//            let storyboardID = "HomeView"
//            let storyboard = UIStoryboard(name: "Main", bundle: nil)
//            guard let newViewController = storyboard.instantiateViewController(withIdentifier: storyboardID) as? HomeViewController else {
//                fatalError("Storyboard ID \(storyboardID)를 가진 ViewController를 찾을 수 없습니다.")
//            }
//            navigationController.setViewControllers([newViewController], animated: false)
//        } else {
//            fatalError("NavigationController를 찾을 수 없습니다.")
//        }

    }
    @IBAction func routineTitleTextField(_ sender: UITextField) {
    }
    @IBOutlet weak var routineTableView: UITableView!
    
    var preVC: UIViewController?
    var tableIndex: IndexPath?
    var databaseIndex: IndexPath?
    
    var startDate: Date?
    var endDate: Date?
    
    var routineTableViewData = [CellData]() // 리스트 선언 부분
    var openedSectionIndex: Int? // 현재 열려 있는 섹션의 인덱스를 저장하는 변수
    
    private var _selectedStartDate: Date?
    private var _selectedEndDate: Date?
    private var selectedRepeatType: RepeatType = .week // Add this property to keep track of the selected repeat type
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 키보드 외부 터치 시 키보드 내리기
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        routineTableView.delegate = self
        routineTableView.dataSource = self
        routineTableView.backgroundColor = .clear
        
        // 여기 이 부분에 데이터 넣어줍니다
        routineTableViewData = [
            CellData(opened: false, title: "Routine", rows: []),
            CellData(opened: false, title: "Start Date", rows: [
                RowData(type: .startDatePicker, data: nil, height: 240)
            ]),
            CellData(opened: false, title: "End Date", rows: [
                RowData(type: .endDatePicker, data: nil, height: 240)
            ]),
//            CellData(opened: false, title: "Repeat", rows: [
//                RowData(type: .repeatWeek, data: nil, height: 44),
//                RowData(type: .repeatWeekPicker, data: nil, height: 60),
//                RowData(type: .repeatMonth, data: nil, height: 44),
//                RowData(type: .repeatMonthPicker, data: nil, height: 280)
//            ], selectedDate: nil)
        ]
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func addRoutine(_ sender: Any) {
        guard let startDate = _selectedStartDate, let endDate = _selectedEndDate else {
            self.view.makeToast("시작 날짜와 종료 날짜를 선택하세요.", duration: 3.0, position: .top)
            return
        }
        
        let routineTitle = (routineTableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? RoutineTitleCell)?.routineTitleLabel.text ?? ""
        if routineTitle.isEmpty {
            self.view.makeToast("루틴 제목을 입력하세요.", duration: 3.0, position: .top)
            return
        }
        
        if self.startDate == nil {
            self.view.makeToast("시작일을 입력하세요.", duration: 3.0, position: .top)
            return
        }
        
        if self.endDate == nil {
            self.view.makeToast("종료일을 입력하세요.", duration: 3.0, position: .top)
            return
        }
        
        if self.startDate! > self.endDate! {
            self.view.makeToast("종료일은 시작일보다 늦어야 합니다.", duration: 3.0, position: .top)
            return
        }
            
        if self.startDate != nil && self.endDate != nil {
            self.addTodosForDateRange(title: routineTitle, startDate: self.startDate!, endDate: self.endDate!)
//            self.navigationController?.popViewController(animated: true)
            
            if let navigationController = self.navigationController {
                let storyboardID = "HomeView"
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                guard let newViewController = storyboard.instantiateViewController(withIdentifier: storyboardID) as? HomeViewController else {
                    fatalError("Storyboard ID \(storyboardID)를 가진 ViewController를 찾을 수 없습니다.")
                }
                navigationController.setViewControllers([newViewController], animated: false)
            } else {
                fatalError("NavigationController를 찾을 수 없습니다.")
            }
        }
        
        return
    }
    
    private func addTodosForDateRange(title: String, startDate: Date, endDate: Date) {
        var currentDate = startDate
        
        while currentDate <= endDate {
            let dateString = DatabaseUtils.shared.dateFormatter(date: currentDate)
            
            DatabaseUtils.shared.addTodo(date: dateString, index: self.tableIndex!, databaseIndex: self.databaseIndex!, todoTitle: title, todoStatus: false) { updatedTodoList in
                
                DatabaseUtils.shared.getNumberOfEvents(date: dateString) { data in
                    if let homeVC = self.preVC as? HomeViewController {
                        homeVC.eventsCountDict[dateString] = Int(data)
                        DispatchQueue.main.async {
                            homeVC.calendarView.reloadData()
                        }
                    }
                }
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
    }
}

extension RoutineViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return routineTableViewData.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return routineTableViewData[section].rows.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            switch indexPath.section {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: "RoutineTitleCell", for: indexPath) as! RoutineTitleCell
                cell.backgroundColor = .clear
                return cell
                
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "StartDateTitleCell", for: indexPath) as! StartDateTitleCell
                cell.chevronButton.tag = indexPath.section
                cell.chevronButton.addTarget(self, action: #selector(chevronButtonTapped(_:)), for: .touchUpInside)
                updateChevronImage(for: cell.chevronButton, in: indexPath.section)
                
                if let selectedDate = routineTableViewData[indexPath.section].selectedDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy년 MM월 dd일"
                    cell.startDateLabel.text = dateFormatter.string(from: selectedDate)
                    self.startDate = selectedDate
                } else {
                    cell.startDateLabel.text = "없음"
                }
                cell.backgroundColor = .clear
                return cell
                
            case 2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "EndDateTitleCell", for: indexPath) as! EndDateTitleCell
                cell.chevronButton.tag = indexPath.section
                cell.chevronButton.addTarget(self, action: #selector(chevronButtonTapped(_:)), for: .touchUpInside)
                updateChevronImage(for: cell.chevronButton, in: indexPath.section)
                
                if let selectedDate = routineTableViewData[indexPath.section].selectedDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy년 MM월 dd일"
                    cell.endDateLabel.text = dateFormatter.string(from: selectedDate)
                    self.endDate = selectedDate
                } else {
                    cell.endDateLabel.text = "없음"
                }
                cell.backgroundColor = .clear
                return cell
                
            case 3:
                let cell = tableView.dequeueReusableCell(withIdentifier: "RepeatTitleCell", for: indexPath) as! RepeatTitleCell
                cell.chevronButton.tag = indexPath.section
                cell.chevronButton.addTarget(self, action: #selector(chevronButtonTapped(_:)), for: .touchUpInside)
                updateChevronImage(for: cell.chevronButton, in: indexPath.section)
                
                cell.backgroundColor = .clear
                return cell
                
            default:
                return UITableViewCell()
            }
        } else {
            let rowData = routineTableViewData[indexPath.section].rows[indexPath.row - 1]
            let cell: UITableViewCell
            
            switch rowData.type {
            case .startDatePicker:
                cell = tableView.dequeueReusableCell(withIdentifier: "StartDatePickerCell", for: indexPath) as! StartDatePickerCell
                (cell as! StartDatePickerCell).delegate = self
                
            case .endDatePicker:
                cell = tableView.dequeueReusableCell(withIdentifier: "EndDatePickerCell", for: indexPath) as! EndDatePickerCell
                (cell as! EndDatePickerCell).delegate = self
                
            case .repeatWeek:
                let weekCell = tableView.dequeueReusableCell(withIdentifier: "RepeatWeekCell", for: indexPath) as! RepeatWeekCell
                weekCell.delegate = self
                weekCell.weekRadioButton.isSelected = (selectedRepeatType == .week)
                
                cell = weekCell
                
            case .repeatWeekPicker:
                cell = tableView.dequeueReusableCell(withIdentifier: "RepeatWeekPickerCell", for: indexPath) as! RepeatWeekPickerCell
                
            case .repeatMonth:
                let monthCell = tableView.dequeueReusableCell(withIdentifier: "RepeatMonthCell", for: indexPath) as! RepeatMonthCell
                monthCell.delegate = self
                monthCell.monthRadioButton.isSelected = (selectedRepeatType == .month)
                
                cell = monthCell
                
            case .repeatMonthPicker:
                cell = tableView.dequeueReusableCell(withIdentifier: "RepeatMonthPickerCell", for: indexPath) as! RepeatMonthPickerCell
            }
            
            cell.backgroundColor = .clear
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.row == 0 {
            toggleSection(indexPath.section)
        }
    }
    
    @objc func chevronButtonTapped(_ sender: UIButton) {
        let section = sender.tag
        toggleSection(section)
    }
    
    func toggleSection(_ section: Int) {
        if section == 3 && !routineTableViewData[section].opened {
            routineTableViewData[section].rows[1].height = 60
            routineTableViewData[section].rows[3].height = 0
            selectedRepeatType = .week // Ensure week repeat is selected when opening the section
        }
        
        routineTableViewData[section].opened.toggle()
        
        if let openedSectionIndex = openedSectionIndex, openedSectionIndex != section {
            routineTableViewData[openedSectionIndex].opened = false
            routineTableView.reloadSections(IndexSet(integer: openedSectionIndex), with: .none)
        }
        
        openedSectionIndex = routineTableViewData[section].opened ? section : nil
        routineTableView.reloadSections(IndexSet(integer: section), with: .none)
    }
        
    
    func updateChevronImage(for button: UIButton, in section: Int) {
        let imageName = routineTableViewData[section].opened ? "chevron.down" : "chevron.right"
        button.setImage(UIImage(systemName: imageName), for: .normal)
    }

    // 섹션 헤더와 푸터의 높이를 0으로 설정하여 여백 없애기
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.0
    }
    
    // row의 높이 조절
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return 44.0 // 타이틀 셀의 높이
        } else {
            return routineTableViewData[indexPath.section].opened ? routineTableViewData[indexPath.section].rows[indexPath.row - 1].height : 0.0
        }
    }
}

class RoutineTitleCell: UITableViewCell {
    var indexPath: IndexPath?
    
    @IBOutlet weak var routineTitleLabel: UITextField!
    
}

class StartDateTitleCell: UITableViewCell {
    
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var chevronButton: UIButton!
}

class StartDatePickerCell: UITableViewCell, FSCalendarDataSource, FSCalendarDelegate {
    @IBOutlet weak var startPickerCalendar: FSCalendar!
    weak var delegate: StartDatePickerCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        startPickerCalendar.firstWeekday = 2 // 월요일 시작
        startPickerCalendar.appearance.headerDateFormat = "YYYY년 MMM"
        startPickerCalendar.appearance.headerMinimumDissolvedAlpha = 0.0
        startPickerCalendar.appearance.titleFont = UIFont.systemFont(ofSize: 17) // 날짜 폰트 크기 조정
        
        // placeholder를 숨기고 모든 날짜를 표시하도록 설정
        startPickerCalendar.placeholderType = .none
        startPickerCalendar.locale = Locale(identifier: "ko_KR") // 한국어로 설정
        startPickerCalendar.dataSource = self
        startPickerCalendar.delegate = self
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        if let selectedStartDate = delegate?.selectedStartDate, selectedStartDate == date {
            delegate?.startDatePickerCell(self, didDeselect: date)
            calendar.deselect(date)
        } else {
            if let selectedStartDate = delegate?.selectedStartDate {
                delegate?.startDatePickerCell(self, didDeselect: selectedStartDate)
                calendar.deselect(selectedStartDate)
            }
            delegate?.startDatePickerCell(self, didSelect: date)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        startPickerCalendar.reloadData()
    }
}

// StartDatePickerCellDelegate 정의
protocol StartDatePickerCellDelegate: AnyObject {
    var selectedStartDate: Date? { get set }
    func startDatePickerCell(_ cell: StartDatePickerCell, didSelect date: Date)
    func startDatePickerCell(_ cell: StartDatePickerCell, didDeselect date: Date)
}

extension RoutineViewController: StartDatePickerCellDelegate {
    var selectedStartDate: Date? {
        get { return _selectedStartDate }
        set {
            _selectedStartDate = newValue
            self.startDate = newValue // 선택된 시작 날짜를 업데이트
        }
    }
    
    func startDatePickerCell(_ cell: StartDatePickerCell, didSelect date: Date) {
        selectedStartDate = date
        routineTableViewData[1].selectedDate = date // Store selected date in data model
        if let startDateTitleCell = routineTableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? StartDateTitleCell {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy년 MM월 dd일"
            startDateTitleCell.startDateLabel.text = dateFormatter.string(from: date)
        }
    }
    
    func startDatePickerCell(_ cell: StartDatePickerCell, didDeselect date: Date) {
        selectedStartDate = nil
        routineTableViewData[1].selectedDate = nil // Clear selected date in data model
        if let startDateTitleCell = routineTableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? StartDateTitleCell {
            startDateTitleCell.startDateLabel.text = "없음"
        }
    }
}

class EndDateTitleCell: UITableViewCell {
    @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var chevronButton: UIButton!
}

class EndDatePickerCell: UITableViewCell, FSCalendarDataSource, FSCalendarDelegate {
    @IBOutlet weak var endPickerCalendar: FSCalendar!
    weak var delegate: EndDatePickerCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        endPickerCalendar.firstWeekday = 2 // 월요일 시작
        endPickerCalendar.appearance.headerDateFormat = "YYYY년 MMM"
        endPickerCalendar.appearance.headerMinimumDissolvedAlpha = 0.0
        endPickerCalendar.appearance.titleFont = UIFont.systemFont(ofSize: 17) // 날짜 폰트 크기 조정
        
        // placeholder를 숨기고 모든 날짜를 표시하도록 설정
        endPickerCalendar.placeholderType = .none
        endPickerCalendar.locale = Locale(identifier: "ko_KR") // 한국어로 설정
        endPickerCalendar.dataSource = self
        endPickerCalendar.delegate = self
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        if let selectedEndDate = delegate?.selectedEndDate, selectedEndDate == date {
            delegate?.endDatePickerCell(self, didDeselect: date)
            calendar.deselect(date)
        } else {
            if let selectedEndDate = delegate?.selectedEndDate {
                delegate?.endDatePickerCell(self, didDeselect: selectedEndDate)
                calendar.deselect(selectedEndDate)
            }
            delegate?.endDatePickerCell(self, didSelect: date)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        endPickerCalendar.reloadData()
    }
}

// EndDatePickerCellDelegate 정의
protocol EndDatePickerCellDelegate: AnyObject {
    var selectedEndDate: Date? { get set }
    func endDatePickerCell(_ cell: EndDatePickerCell, didSelect date: Date)
    func endDatePickerCell(_ cell: EndDatePickerCell, didDeselect date: Date)
}

extension RoutineViewController: EndDatePickerCellDelegate {
    var selectedEndDate: Date? {
        get { return _selectedEndDate }
        set {
            _selectedEndDate = newValue
            self.endDate = newValue // 선택된 종료 날짜를 업데이트
        }
    }
    
    func endDatePickerCell(_ cell: EndDatePickerCell, didSelect date: Date) {
        selectedEndDate = date
        routineTableViewData[2].selectedDate = date // Store selected date in data model
        if let endDateTitleCell = routineTableView.cellForRow(at: IndexPath(row: 0, section: 2)) as? EndDateTitleCell {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy년 MM월 dd일"
            endDateTitleCell.endDateLabel.text = dateFormatter.string(from: date)
        }
    }

    func endDatePickerCell(_ cell: EndDatePickerCell, didDeselect date: Date) {
        selectedEndDate = nil
        routineTableViewData[2].selectedDate = nil // Clear selected date in data model
        if let endDateTitleCell = routineTableView.cellForRow(at: IndexPath(row: 0, section: 2)) as? EndDateTitleCell {
            endDateTitleCell.endDateLabel.text = "없음"
        }
    }
}

class RepeatTitleCell: UITableViewCell {
    var indexPath: IndexPath?
    
    @IBOutlet weak var repeatTypeLabel: UILabel!
    
    @IBOutlet weak var chevronButton: UIButton!
}

class RepeatWeekCell: UITableViewCell {
    var indexPath: IndexPath?
    weak var delegate: RepeatCellDelegate?
    
    @IBOutlet weak var weekRadioButton: UIButton!
    
    @IBAction func tappedRadioButton(_ sender: UIButton) {
        delegate?.didTapRepeatWeekCell(self)
    }
}

class RepeatWeekPickerCell: UITableViewCell {
    var indexPath: IndexPath?
    
    var selectedDays: [String: Bool] = [ "월": true, "화": true, "수": true, "목": true, "금": true, "토": true, "일": true ]
    var configuration = UIButton.Configuration.filled()
    
    @IBOutlet var dayButtons: [UIButton]!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configureButtons()
    }
    
    func configureButtons() {
        let titles = ["월", "화", "수", "목", "금", "토", "일"]
        
        for (index, button) in dayButtons.enumerated() {
            button.tag = index
            
            button.setTitle(titles[index], for: .normal)
//            button.setTitleColor(.black, for: .normal)
//            button.setTitleColor(.white, for: .selected)
            
            configuration.background.backgroundColor = UIColor(named: "DeepGreen")
            configuration.cornerStyle = .capsule
            button.configuration = configuration
            
            button.addTarget(self, action: #selector(self.checkButton(_:)), for: .touchUpInside)
        }
    }
    
    @objc private func checkButton(_ sender: UIButton) {
        let titles = ["월", "화", "수", "목", "금", "토", "일"]
        let day = titles[sender.tag]
        
        if selectedDays[day] == true && selectedDays.values.filter({ $0 }).count == 1 {
            // 최소 하나의 버튼이 선택된 상태를 유지하도록 함
            if let parentView = self.superview as? UITableView {
                parentView.makeToast("최소 하나 이상의 날짜를 선택해야 합니다.", duration: 3.0, position: .bottom)
            }
            return
        }
        
        selectedDays[day]?.toggle()
        
        configuration.background.backgroundColor = selectedDays[day]! ? UIColor(named: "DeepGreen") : UIColor(named: "GrayGreen")
        sender.configuration = configuration
    }
}

class RepeatMonthCell: UITableViewCell {
    var indexPath: IndexPath?
    weak var delegate: RepeatCellDelegate?
    
    @IBOutlet weak var monthRadioButton: UIButton!
    
    @IBAction func tappedRadioButton(_ sender: UIButton) {
        delegate?.didTapRepeatMonthCell(self)
    }
}

class RepeatMonthPickerCell: UITableViewCell, FSCalendarDataSource, FSCalendarDelegate {
    var indexPath: IndexPath?
    var selectedDates: [Date] = [] {
        didSet {
            selectDates(selectedDates)
        }
    }
    
    @IBOutlet weak var monthPickerCalendar: FSCalendar!
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // 현재 날짜와 같은 일을 가진 날짜를 선택하도록 설정
        selectCurrentDayInAnyMonth()
        
        // 필요에 따라 추가 설정
        monthPickerCalendar.firstWeekday = 4
        monthPickerCalendar.appearance.headerDateFormat = "yyyy MMM"
        monthPickerCalendar.appearance.headerMinimumDissolvedAlpha = 0.0
        
        // placeholder를 숨기고 모든 날짜를 표시하도록 설정
        monthPickerCalendar.placeholderType = .none
        monthPickerCalendar.locale = Locale(identifier: "ko_KR") // 한국어로 설정
        monthPickerCalendar.dataSource = self
        monthPickerCalendar.delegate = self
        
        // 레이아웃 업데이트 추가
        monthPickerCalendar.setNeedsLayout()
        monthPickerCalendar.layoutIfNeeded()
    }
    
    func minimumDate(for calendar: FSCalendar) -> Date {
        // 캘린더의 최소 날짜를 설정 (임의의 과거 날짜)
        return Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!
    }

    func maximumDate(for calendar: FSCalendar) -> Date {
        // 캘린더의 최대 날짜를 설정 (임의의 미래 날짜)
        return Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 31))!
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        if !selectedDates.contains(date) {
            selectedDates.append(date)
        }
    }

    func calendar(_ calendar: FSCalendar, didDeselect date: Date) {
        if let index = selectedDates.firstIndex(of: date) {
            selectedDates.remove(at: index)
        }
        
        // 선택된 날짜가 없는 경우 경고 메시지 표시
        if selectedDates.isEmpty {
            
            if let parentView = self.superview as? UITableView {
                parentView.makeToast("최소 하나 이상의 날짜를 선택해야 합니다.", duration: 3.0, position: .bottom)
            }
            
            calendar.select(date)
            selectedDates.append(date)
        }
    }

    private func selectCurrentDayInAnyMonth() {
        if selectedDates.isEmpty {
            let today = Date()
            let calendar = Calendar.current
            let currentDay = calendar.component(.day, from: today)
            
            // 현재 월의 날짜를 선택하는 것으로 시작
            let startDateComponents = DateComponents(year: 2020, month: 1, day: currentDay)
            if let startDate = calendar.date(from: startDateComponents) {
                monthPickerCalendar.select(startDate)
                selectedDates.append(startDate)
            }
        } else {
            selectDates(selectedDates)
        }
    }

    private func selectDates(_ dates: [Date]) {
        for date in dates {
            monthPickerCalendar.select(date)
        }
    }
}

// Define RepeatCellDelegate protocol
protocol RepeatCellDelegate: AnyObject {
    func didTapRepeatWeekCell(_ cell: RepeatWeekCell)
    func didTapRepeatMonthCell(_ cell: RepeatMonthCell)
}

extension RoutineViewController: RepeatCellDelegate {
    func didTapRepeatWeekCell(_ cell: RepeatWeekCell) {
        routineTableViewData[3].rows[1].height = 60
        routineTableViewData[3].rows[3].height = 0
        routineTableViewData[3].opened = true
        selectedRepeatType = .week
        routineTableView.reloadSections(IndexSet(integer: 3), with: .none)
    }

    func didTapRepeatMonthCell(_ cell: RepeatMonthCell) {
        routineTableViewData[3].rows[1].height = 0
        routineTableViewData[3].rows[3].height = 280
        routineTableViewData[3].opened = true
        selectedRepeatType = .month
        routineTableView.reloadSections(IndexSet(integer: 3), with: .none)
    }
}

struct CellData {
    var opened: Bool
    var title: String
    var rows: [RowData]
    var selectedDate: Date? // Add this to store selected date
}

struct RowData {
    var type: CellType
    var data: String?
    var height: CGFloat
}

enum CellType {
    case startDatePicker
    case endDatePicker
    case repeatWeek
    case repeatWeekPicker
    case repeatMonth
    case repeatMonthPicker
}

enum RepeatType {
    case week
    case month
}
