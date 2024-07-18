//
//  ProfileViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/12.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase


class ProfileViewController: UIViewController, UIGestureRecognizerDelegate {
    var email: String? = DatabaseUtils.shared.email
    var preVC: String?
    
    
    @IBOutlet weak var profileImageButton: UIButton!
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var nicknameTextField: UITextField!
    @IBOutlet weak var setProfileButton: UIButton!
    @IBOutlet weak var infoLabel: UILabel!
    
    
    @IBAction func goBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func setProfileButtonTouched(_ sender: UIButton) {
        self.setProfileButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Change 2.0 to the desired number of seconds
            self.setProfileButton.isEnabled = true
        }
        
        if (nicknameTextField.text == "") { // 입력된 이름이 없음
            // 알림 발생
            self.view.makeToast("닉네임을 입력해주세요.", duration: 3.0, position: .top)
            self.setProfileButton.isEnabled = true
        } else { // 입력된 이름이 있음
            if (preVC != "Home") {  // 초기 이름 설정
                let index = Int(DatabaseUtils.shared.catNum)
                DatabaseUtils.shared.updateTamedCat(index: index!, name: nicknameTextField.text!) {_ in }
                
                // 홈 뷰로 이동
                let homeVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HomeView")
                self.navigationController!.setViewControllers([homeVC], animated: true)
            }
            else {  // 프로필 수정
                let catName = CatInfo.catTamedList[DatabaseUtils.shared.catNum]
                if catName != "" { // 고양이 이름을 바꾸는 경우
                    if nicknameTextField.text != catName { // 바꾸려는 이름이 기존 이름과 다른 경우
                        DatabaseUtils.shared.updatePoint(change: -1000, cancel: false) { updatedPoint in
                            if updatedPoint >= 0 {
                                let index = Int(DatabaseUtils.shared.catNum)
                                DatabaseUtils.shared.updateTamedCat(index: index!, name: self.nicknameTextField.text!) {_ in
                                    self.view.makeToast("이름이 변경되었습니다.", duration: 3.0, position: .top)
                                }
                            }
                            else {
                                self.view.makeToast("포인트가 부족합니다.", duration: 3.0, position: .top)
                            }
                        }
                    }
                    else {  // 바꾸려는 이름이 기존 이름과 같은 경우
                        self.view.makeToast("지금과 같은 이름이에요!", duration: 3.0, position: .top)
                    }
                }
                else { // 처음으로 고양이 이름을 설정하는 경우
                    let index = Int(DatabaseUtils.shared.catNum)
                    DatabaseUtils.shared.updateTamedCat(index: index!, name: nicknameTextField.text!) { _ in
                        
                        self.view.endEditing(true)
                        self.view.makeToast("이름이 설정되었습니다.", duration: 3.0, position: .top)
                        
                        self.setProfileButton.setTitle("\(1000) 포인트로 이름 바꾸기", for: .normal)
                        self.setProfileButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
                        self.setProfileButton.semanticContentAttribute = .forceLeftToRight
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if (preVC == "Home") {
            navigationItem.title = "프로필 수정"
            
            profileImageButton.isEnabled = true
            let catName = CatInfo.catTamedList[DatabaseUtils.shared.catNum]
            self.nicknameTextField.text = catName
            infoLabel.isHidden = true
            
            if catName == "" {
                setProfileButton.setTitle("완료", for: .normal)
                setProfileButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                setProfileButton.semanticContentAttribute = .forceRightToLeft
            }
            else {
                setProfileButton.setTitle("\(1000) 포인트로 이름 바꾸기", for: .normal)
                setProfileButton.setImage(UIImage(systemName: "heart.fill"), for: .normal)
                setProfileButton.semanticContentAttribute = .forceLeftToRight
            }
            
            // 레이아웃을 업데이트하여 이미지와 타이틀이 제대로 표시되도록 합니다.
            setProfileButton.layoutIfNeeded()
        }
        else {
            profileImageButton.isEnabled = false
        }
        
        // 프로필 이미지 설정
        let catNum = DatabaseUtils.shared.catNum
        let profileImage = "cat\(catNum)_sitting_01"
        let image = UIImage(named: profileImage)
        self.profileImageButton.setImage(image, for: .normal)
        
        // 이메일 설정
        self.emailLabel.text = self.email
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        // Do any additional setup after loading the view.
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        if preVC != "Home" {
            DatabaseUtils.shared.initializeData(for: Auth.auth().currentUser, completion: {})
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ProfileToCollectionSegue" {
            if let nextVC = segue.destination as? CatCollectionViewController {
                nextVC.preVC = "Profile"
            }
        }
    }
    
    
    // 빈화면 터치 시 키보드 내리기
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
