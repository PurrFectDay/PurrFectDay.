//
//  ShopViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/06/02.
//

import UIKit


class ShopViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBAction func goBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    @IBOutlet weak var pointButton: UIButton!
    
    @IBOutlet weak var tabBarCollectionView: UICollectionView!
    @IBOutlet weak var highlightView: UIView!
    @IBOutlet weak var pageCollectionView: UICollectionView!
    
    // 하이라이트 뷰 설정: 색상 설정 및 초기화
    private let highlight: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(named: "DeepGreen")
        return view
    }()
    // 하이라이트 뷰의 리딩 및 트레일링 제약 조건
    private var highlightViewLeadingConstraint: NSLayoutConstraint?
    private var highlightViewTrailingConstraint: NSLayoutConstraint?
    private var selectedTabIndex: IndexPath? // 선택된 탭의 인덱스를 추적
    
    private var point: Int?
    let categoryTitle: [[Any]] = [
        ["wall", "벽지"], ["floor", "바닥"], ["molding", "몰딩"], ["window", "창문"], ["rug", "러그"],
        ["table", "테이블"], ["chair", "의자"], ["sofa", "소파"],
        ["lightning", "조명"], ["plant", "식물"], ["catTower", "캣타워"]
    ]
    
    var shopList: [String: [Item]] = DatabaseUtils.shared.shopList {
        didSet {
            for (category, items) in shopList {
                shopList[category] = items.sorted { $0.imageName < $1.imageName }
            }
            self.pageCollectionView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        DatabaseUtils.shared.getPoint() { data in
            self.point = data
            self.pointButton.setTitle(String(self.point ?? 0), for: .normal)
        }
        
        DatabaseUtils.shared.getShop(completion: { data in
            self.shopList = data ?? [:]
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarCollectionView.backgroundColor = .clear
        pageCollectionView.layer.cornerRadius = 20
        pageCollectionView.backgroundColor = .clear
        
        tabBarCollectionView.delegate = self
        tabBarCollectionView.dataSource = self
        pageCollectionView.delegate = self
        pageCollectionView.dataSource = self
        
        // 하이라이트 뷰 설정
        setupHighlightView()
        
        // PageCollectionView의 레이아웃 설정
        if let layout = pageCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            layout.scrollDirection = .horizontal
            pageCollectionView.isPagingEnabled = true
        }
        
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupInitialSelection()
    }
    
    // 하이라이트 뷰 설정 메소드
    private func setupHighlightView() {
        // 하이라이트 뷰를 하이라이트 뷰에 추가하고 제약 조건 설정
        highlightView.addSubview(highlight)
        highlight.translatesAutoresizingMaskIntoConstraints = false
        
        highlightViewLeadingConstraint = highlight.leadingAnchor.constraint(equalTo: highlightView.leadingAnchor)
        highlightViewTrailingConstraint = highlight.trailingAnchor.constraint(equalTo: highlightView.trailingAnchor)
        
        NSLayoutConstraint.activate([
            highlight.bottomAnchor.constraint(equalTo: highlightView.topAnchor),
            highlight.heightAnchor.constraint(equalToConstant: 2),  // 하이라이트 뷰의 높이를 2로 설정
            highlightViewLeadingConstraint!,    // 리딩 제약 조건 활성화
            highlightViewTrailingConstraint!    // 트레일링 제약 조건 활성화
        ])
    }
    
    // 초기 선택 설정 메소드
    private func setupInitialSelection() {
        // 첫 번째 인덱스를 선택하고 하이라이트 뷰 업데이트
        let firstIndex = IndexPath(item: 0, section: 0) // 첫 번째 아이템의 인덱스
        tabBarCollectionView.selectItem(at: firstIndex, animated: false, scrollPosition: .right)    // 첫 번째 아이템을 선택
        selectedTabIndex = firstIndex // 첫 번째 아이템을 선택된 탭 인덱스로 설정
        if let cell = tabBarCollectionView.cellForItem(at: firstIndex) {     // 선택한 셀을 가져옴
            updateHighlightViewConstraints(for: cell)   // 하이라이트 뷰 제약 조건 업데이트
        }
    }
    
    // 하이라이트 뷰의 제약 조건 업데이트 메소드
    private func updateHighlightViewConstraints(for cell: UICollectionViewCell) {
        // 기존 제약 조건 비활성화
        highlightViewLeadingConstraint?.isActive = false
        highlightViewTrailingConstraint?.isActive = false
        
        // 새로운 제약 조건 설정
        highlightViewLeadingConstraint = highlight.leadingAnchor.constraint(equalTo: cell.leadingAnchor)
        highlightViewTrailingConstraint = highlight.trailingAnchor.constraint(equalTo: cell.trailingAnchor)
        
        // 새로운 제약 조건 활성화
        highlightViewLeadingConstraint?.isActive = true
        highlightViewTrailingConstraint?.isActive = true
        
        // 애니메이션을 통해 뷰 업데이트
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()  // 레이아웃 업데이트
        }
    }
    
    func selectTab(at indexPath: IndexPath) {
        guard let cell = tabBarCollectionView.cellForItem(at: indexPath) else { return }
        selectedTabIndex = indexPath // 선택된 탭 인덱스 업데이트
        updateHighlightViewConstraints(for: cell)
        pageCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        DispatchQueue.main.async {
            self.pageCollectionView.reloadData() // 페이지를 다시 로드하여 변경사항 반영
        }
    }
}

extension ShopViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.categoryTitle.count // 카테고리별로 섹션 수
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == tabBarCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TabBarCollectionViewCell", for: indexPath) as! TabBarCollectionViewCell
            
            let categoryTitle = self.categoryTitle[indexPath.row][1] as! String
            cell.configure(with: categoryTitle)
            return cell
            
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PageCollectionViewCell", for: indexPath) as! PageCollectionViewCell
            cell.category = self.categoryTitle[indexPath.row][0] as? String
            cell.delegate = self
            cell.tag = indexPath.row
            cell.reloadTableView()
            return cell
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
        
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == tabBarCollectionView {
            let title = "Tab \(indexPath.item)"
            let size = title.size(withAttributes: [.font: UIFont.systemFont(ofSize: 17)])
            return CGSize(width: size.width + 20, height: collectionView.frame.height)
        } else {
            return CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
        }
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == tabBarCollectionView {
//            guard let cell = tabBarCollectionView.cellForItem(at: indexPath) else { return }
//            selectedTabIndex = indexPath // 선택된 탭 인덱스 업데이트
//            updateHighlightViewConstraints(for: cell)
//            pageCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            selectTab(at: indexPath)
        }
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == pageCollectionView {
            // 레이아웃과 셀의 너비를 가져옴
            let layout = self.pageCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
            let cellWidth = layout.itemSize.width + 38
            let proposedContentOffset = targetContentOffset.pointee     // 제안된 콘텐츠 오프셋
            let targetIndex = round((proposedContentOffset.x + scrollView.contentInset.left) / cellWidth)   // 목표 인덱스 계산
            let numberOfItems = collectionView(self.pageCollectionView, numberOfItemsInSection: 0)
            
            // targetIndex가 범위 내에 있는지 확인
            guard targetIndex < CGFloat(numberOfItems) else { return }
            
            // 목표 콘텐츠 오프셋 설정
            targetContentOffset.pointee = CGPoint(
                x: targetIndex * cellWidth - scrollView.contentInset.left,
                y: scrollView.contentInset.top
            )
            
            // 목표 인덱스의 인덱스 경로 생성
            let indexPath = IndexPath(item: Int(targetIndex), section: 0)
            tabBarCollectionView.selectItem(at: indexPath, animated: true, scrollPosition: .bottom)
            selectedTabIndex = indexPath // 선택된 탭 인덱스 업데이트
            collectionView(tabBarCollectionView, didSelectItemAt: indexPath)
            tabBarCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == tabBarCollectionView {
            // tabBarCollectionView가 스크롤 중일 때 하이라이트 뷰 업데이트 방지
            if let selectedTabIndex = selectedTabIndex, let cell = tabBarCollectionView.cellForItem(at: selectedTabIndex) {
                updateHighlightViewConstraints(for: cell)
            }
        }
    }
}

class TabBarCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var tabBarButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tabBarButton.addTarget(self, action: #selector(tabBarButtonTapped), for: .touchUpInside)
    }
    
    func configure(with title: String) {
        tabBarButton.setTitle(title, for: .normal)
        tabBarButton.invalidateIntrinsicContentSize()
    }
    
    @objc private func tabBarButtonTapped() {
        if let collectionView = superview as? UICollectionView,
           let indexPath = collectionView.indexPath(for: self) {
            // 선택한 아이템을 중앙으로 스크롤하고 선택 상태로 설정
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
            if let shopViewController = collectionView.delegate as? ShopViewController {
                shopViewController.selectTab(at: indexPath)
            }
        }
    }
}

class PageCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var shopTableView: UITableView!
    
    weak var delegate: PageDelegate?
    var category: String?
    
    override func awakeFromNib() {
            super.awakeFromNib()
        shopTableView.delegate = self
        shopTableView.dataSource = self
    }
    
    func reloadTableView() {
        DispatchQueue.main.async { [self] in
            self.shopTableView.reloadData()
            self.shopTableView.layoutIfNeeded()
        }
    }
}

extension PageCollectionViewCell: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let category = category, let shopList = delegate?.getShopList() else { return 0 }
        return shopList[category]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ShopTableViewCell", for: indexPath) as! ShopTableViewCell
        guard let category = category, let shopList = delegate?.getShopList() else { return cell }
        
        cell.purchaseDelegate = self
        cell.placeDelegate = self
        cell.tableIndex = indexPath.row
        cell.pageIndex = self.tag
        
        // 아이템 이미지 설정
        let item = shopList[category]?[indexPath.row]
        cell.itemImageView.image = UIImage(named: item?.imageName ?? "")
        
        // 아이템 가격 설정
        let price = shopList[category]?[indexPath.row].price ?? 0
        cell.priceButton.setTitle(String(price), for: .normal)
        
        // 배치하기, 구매하기 버튼
        if let isPurchased = shopList[category]?[indexPath.row].isPurchased, isPurchased {    // 구매된 물건일 경우
            cell.purchaseButton.isEnabled = false   // 구매하기 버튼 비활성화
            cell.purchaseButton.isHidden = true     // 구매하기 버튼 숨기기
            
            cell.placeButton.isEnabled = true       // 배치하기 버튼 활성화
            cell.placeButton.isHidden = false       // 배치하기 버튼 보이기
            
            cell.placeButton.layer.borderColor = UIColor(named: "BabyPink")?.cgColor
            cell.placeButton.layer.borderWidth = 2.0 // 테두리 너비
            
            if let isPlaced = shopList[category]?[indexPath.row].isPlaced, isPlaced {   // 물건이 배치 상태일 경우
                cell.placeButton.setTitle("배치완료", for: .normal) // 배치된 상태 표시
                cell.placeButton.backgroundColor = UIColor(named: "BabyPink")
                cell.placeButton.setTitleColor(UIColor(named: "Cream"), for: .normal)
                cell.placeButton.configuration?.image = UIImage(systemName: "cube.fill")!.withTintColor(UIColor(named: "Cream")!, renderingMode: .alwaysOriginal)
            }
            else {  // 물건이 배치되지 않은 상태일 경우
                cell.placeButton.setTitle("배치하기", for: .normal) // 배치하기 버튼
                cell.placeButton.backgroundColor = UIColor(named: "Cream")
                cell.placeButton.setTitleColor(UIColor(named: "BabyPink"), for: .normal)
                cell.placeButton.configuration?.image = UIImage(systemName: "cube")!.withTintColor(UIColor(named: "BabyPink")!, renderingMode: .alwaysOriginal)
            }
        }
        else {  // 구매하지 않은 물건일 경우
            cell.purchaseButton.isEnabled = true    // 구매하기 버튼 활성화
            cell.purchaseButton.isHidden = false    // 구매하기 버튼 보이기
            cell.placeButton.isEnabled = false
            cell.placeButton.isHidden = true
        }
        
        return cell
    }
}

class ShopTableViewCell: UITableViewCell {
    @IBOutlet weak var itemImageView: UIImageView!
    @IBOutlet weak var priceButton: UIButton!
    @IBOutlet weak var placeButton: UIButton!
    @IBOutlet weak var purchaseButton: UIButton!
    
    var purchaseDelegate: PurchaseDelegate?
    var placeDelegate: PlaceDelegate?
    
    var pageIndex: Int?
    var tableIndex: Int = 0
    
    @IBAction func placeItem(_ sender: UIButton) {
        placeDelegate?.placeButtonTapped(categoryIndex: pageIndex!, itemIndex: tableIndex)
    }
    
    @IBAction func purchaseItem(_ sender: UIButton) {
        if let pageIndex = pageIndex {
            purchaseDelegate?.purchaseButtonTapped(categoryIndex: pageIndex, itemIndex: tableIndex)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupShadowForImageView()
    }
    
    private func setupShadowForImageView() {
        itemImageView.layer.shadowColor = UIColor.black.cgColor // 그림자 색상
        itemImageView.layer.shadowOpacity = 0.7 // 그림자 불투명도
        itemImageView.layer.shadowOffset = CGSize(width: 3, height: 3) // 그림자 오프셋
        itemImageView.layer.shadowRadius = 4 // 그림자 반경
        itemImageView.layer.masksToBounds = false
    }
}

protocol PageDelegate: AnyObject {
    func getShopList() -> [String: [Item]]
    func getSelectedCategory() -> String?
    func updatePointButton(with point: Int)
    func presentAlert(title: String, message: String)
    
    func updateShopList(with shopList: [String: [Item]])
}

extension ShopViewController: PageDelegate {
    // StoreViewControllerDelegate 메서드 구현
    func getShopList() -> [String: [Item]] {
        return shopList
    }
    
    func getSelectedCategory() -> String? {
        guard let selectedTabIndex = selectedTabIndex else { return nil }
        return categoryTitle[selectedTabIndex.row][0] as? String
    }
    
    func updatePointButton(with point: Int) {
        pointButton.setTitle(String(point), for: .normal)
    }
    
    func presentAlert(title: String, message: String) {
        AlertUtils.showOkAlert(view: self, title: title, message: message, completion: { _ in })
    }
    
    func updateShopList(with shopList: [String: [Item]]) {
        self.shopList = shopList
    }
}

protocol PlaceDelegate {
    func placeButtonTapped(categoryIndex: Int, itemIndex: Int)
}

protocol PurchaseDelegate {
    func purchaseButtonTapped(categoryIndex: Int, itemIndex: Int)
}

extension PageCollectionViewCell: PurchaseDelegate, PlaceDelegate {
    func purchaseButtonTapped(categoryIndex: Int, itemIndex: Int) {
        guard let shopList = delegate?.getShopList() else { return }
        guard let category = category else { return }
        let price = shopList[category]?[itemIndex].price ?? 0
        
        DatabaseUtils.shared.updatePoint(change: Int(-price), cancel: false) { pointData in
            if pointData > 0 {
                self.delegate?.updatePointButton(with: pointData) // Update the point button
                
                DatabaseUtils.shared.purchaseItem(categoryIndex: categoryIndex, itemIndex: itemIndex) { shopData in
                    self.delegate?.updateShopList(with: shopData ?? shopList)
                }
            }
            else if pointData == -3 { // 구매하려는 아이템의 가격이 잔여 포인트보다 높은 경우
                self.delegate?.presentAlert(title: "구매 실패", message: "포인트가 부족합니다.")
            }
        }
    }
    
    func placeButtonTapped(categoryIndex: Int, itemIndex: Int) {
        guard let shopList = delegate?.getShopList() else { return }
        guard let category = category else { return }
        
        DatabaseUtils.shared.updatePlacement(categoryIndex: categoryIndex, itemIndex: itemIndex, state: !shopList[category]![itemIndex].isPlaced) { shopData in
            self.delegate?.updateShopList(with: shopData!)
        }
    }
}
