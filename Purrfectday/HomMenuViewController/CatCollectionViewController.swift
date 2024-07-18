//
//  CatCollectionViewController.swift
//  Purrfectday
//
//
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseDatabase

class CatCollectionViewController: UIViewController {
    
    @IBOutlet weak var catCollectionView: UICollectionView!
    @IBOutlet var pointButton: UIButton!
    @IBAction func goBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    var preVC: String?
    let catCollectionList = CatInfo.catCollectionList
    var catTamedList = CatInfo.catTamedList
    private var point = 0 {
        didSet {
            self.pointButton.setTitle(String(self.point), for: .normal)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        catCollectionView.backgroundColor = .clear
        catCollectionView.delegate = self
        catCollectionView.dataSource = self
        catCollectionView.collectionViewLayout = UICollectionViewFlowLayout()
        
        if (preVC == "Profile") {
            navigationItem.title = "프로필 수정"
            pointButton.isHidden = true
        }
        
        // 전체 포인트 불러오기
        DatabaseUtils.shared.getPoint() { pointData in
            self.point = pointData
            self.pointButton.setTitle(String(self.point), for: .normal)
        }
    }    
}

class CatCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var catCollectionImage: UIImageView!
    @IBOutlet weak var catNameLabel: UILabel!
}

extension CatCollectionViewController:  UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if (preVC == "Profile") {
            // 고양이를 길들인 경우 길들인 고양이들만 프로필로 설정 가능하도록 제한
            return self.catTamedList.count
        }
        return catCollectionList.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CatCollectionViewCell", for: indexPath) as! CatCollectionViewCell
        var index = indexPath.row + 1
        
        // 길들인 고양이들의 이미지만 컬렉션 뷰에 나타나도록 제한
        if (preVC == "Profile") {
            let sortedKeys = self.catTamedList.keys.sorted()
            index = Int(sortedKeys[indexPath.row])!
            
            let name = self.catTamedList[String(format: "%02d", index)]
            if name != "" {
                cell.catNameLabel.text = name
            }
            else {
                cell.catNameLabel.text = catCollectionList[index]?.catName as? String
            }
        }
        else {
            cell.catNameLabel.text = catCollectionList[index]?.catName as? String
        }
        
        cell.catCollectionImage.image = UIImage(named: catCollectionList[index]!.imageName)
        
        cell.layer.cornerRadius = 20
        
        // 이미 추가된 Blur Effect View를 제거
        for subview in cell.subviews {
            if subview is UIVisualEffectView {
                subview.removeFromSuperview()
            }
        }
        
        // 길들이지 않은 고양이에게 blur effect
        let viewBlurEffect = UIVisualEffectView()
        //Blur Effect는 .light 외에도 .dark, .regular 등이 있음
        viewBlurEffect.effect = UIBlurEffect(style: .light)
        viewBlurEffect.alpha = 0.4
        viewBlurEffect.frame = cell.bounds
        
        let key = String(format: "%02d", index)
        if !self.catTamedList.keys.contains(key) {
            //viewMain에 Blur 효과가 적용된 EffectView 추가
            cell.addSubview(viewBlurEffect)
            
            // catNameLabel을 중앙 하단에 위치시키기
//            cell.catNameLabel.translatesAutoresizingMaskIntoConstraints = false
//            NSLayoutConstraint.activate([
//                cell.catNameLabel.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
//                cell.catNameLabel.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -10)
//            ])
//            
//            cell.addSubview(cell.catNameLabel)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let index = indexPath.row + 1
        let catImage = self.catCollectionList[index]?.imageName
        let catName = self.catCollectionList[index]?.catName
        let catStory = self.catCollectionList[index]?.description
        
        guard let catCollectionDetailView = self.storyboard?.instantiateViewController(identifier: "CatCollectionDetailView") as? CatCollectionDetailViewController else { return }
        catCollectionDetailView.catImage = catImage!
        catCollectionDetailView.catName = catName!
        catCollectionDetailView.catStory = catStory!
        catCollectionDetailView.index = indexPath.row
        
        if preVC != "Profile" {
            // catCollectionView 상의 pointButton의 포인트가 고양이 길들이기 버튼 누른 후 업데이트 되도록 클로저 설정
            catCollectionDetailView.updatedDataSendClosure = { updatedPoint, tamedData in
                self.point = updatedPoint
                self.catTamedList = tamedData
                self.catCollectionView.reloadData()
            }
            self.present(catCollectionDetailView, animated: false)
        }
        else {
            let sortedKeys = self.catTamedList.keys.sorted()
            let index = Int(sortedKeys[indexPath.row])!
            DatabaseUtils.shared.updateMainCat(index: index) { num in }
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let length = collectionView.frame.width / 2.1
        let size = CGSize(width: length, height: length)
        
        return size
    }
}

class CatCollectionDetailViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var popupView: UIView!
    @IBOutlet weak var catImageView: UIImageView!
    @IBOutlet weak var catNameLabel: UILabel!
    @IBOutlet weak var catStoryLabel: UILabel!
    @IBOutlet var catTameButton: UIButton!
    
    var catImage = ""
    var catName = ""
    var catStory = ""
    var index = 0
    var updatedDataSendClosure: ((_ point: Int, _ tamedData: [String:String]) -> Void)? // 전체 포인트 업데이트 클로저
    
    @IBAction func closeByTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: view)
        
        // 터치된 위치가 특정 뷰의 프레임 밖인지 확인
        if !popupView.frame.contains(location) {
            dismiss(animated: false, completion: nil)
        }
    }
    
    @IBAction func goBack(_ sender: UIButton) {
        self.dismiss(animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.catImageView.image = UIImage(named: catImage)
        self.catNameLabel.text = catName
        self.catStoryLabel.text = catStory
        
        self.catTameButton.layer.cornerRadius = 20
        // 고양이를 이미 길들인 경우 길들이기 버튼 비활성화
        if (CatInfo.catTamedList[String(format: "%02d", self.index + 1)] != nil) {
            catTameButton.isEnabled = false
        }
        // 길들이기 버튼에 고양이 포인트 표시
        self.catTameButton.setTitle("\(CatInfo.catCollectionList[index + 1]!.point) 포인트로 길들이기", for: .normal)
        
        // 길들이지 않은 고양이에게 blur effect
//        let key = String(format: "%02d", index + 1)
//        if !CatInfo.catTamedList.keys.contains(key) {
//            let viewBlurEffect = UIVisualEffectView()
//            
//            //Blur Effect는 .light 외에도 .dark, .regular 등이 있음
//            viewBlurEffect.effect = UIBlurEffect(style: .light)
//            viewBlurEffect.alpha = 0.4
//            viewBlurEffect.frame = catImageView.bounds
//            
//            
//            //viewMain에 Blur 효과가 적용된 EffectView 추가
//            catImageView.addSubview(viewBlurEffect)
//        }
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    @IBAction func tameCatButton(_ sender: Any) {
        let price = CatInfo.catCollectionList[index + 1]!.point
        
        DatabaseUtils.shared.updatePoint(change: -price, cancel: false) { pointData in
            if pointData >= 0 {
                
                DatabaseUtils.shared.updateTamedCat(index: self.index + 1, name: "") { tamedData in
                    self.catTameButton.isEnabled = false
                    
                    // 클로저로 포인트 업데이트
                    self.updatedDataSendClosure?(pointData, tamedData)
                    self.dismiss(animated: false)
                }
            }
        }
    }
}
