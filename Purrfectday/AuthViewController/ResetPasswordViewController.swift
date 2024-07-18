//
//  ResetPasswordViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/12.
//

import UIKit
import Toast_Swift
import FirebaseAuth

class ResetPasswordViewController: UIViewController {
    var handle: AuthStateDidChangeListenerHandle?
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var resetPasswordButton: UIButton!
    
    
    // 뒤로가기
    @IBAction func goBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    // 비밀번호 재설정하기
    var emailSendingFailed = false
    @IBAction func sendResetPasswordEmail(_ sender: UIButton) {
        self.resetPasswordButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Change 2.0 to the desired number of seconds
            self.resetPasswordButton.isEnabled = true
        }
        
        view.endEditing(true)
        
        // emailTextField의 text 값 가져오기
        guard let email = emailTextField.text, !email.isEmpty else {
            // 이메일 필드가 비어 있을 경우 토스트 메시지 표시
            self.view.makeToast("이메일을 입력해주세요.", duration: 3.0, position: .top)
            return
        }
        
        // 이메일 형식 검증
        if AuthUtils.isValidEmail(email) { // 유효한 이메일 형식
            NSLog("valid email")
            // 재설정 이메일 전송
            AuthUtils.resetPassword(email: email) { success in
                if success { // 이메일 전송 성공
                    // 팝업 띄우기
                    self.performSegue(withIdentifier: "PopupSegue", sender: nil)
                } else { // 이메일 전송 실패
                    self.view.makeToast("이메일 전송에 실패했습니다.", duration: 3.0, position: .top)
                }
            }
        } else { // 유효하지 않은 이메일 형식
            NSLog("not valid email")
            self.view.makeToast("유효하지 않은 이메일 형식입니다.", duration: 3.0, position: .top)
            
            return
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // [START auth_listener] 리스너 연결
        handle = Auth.auth().addStateDidChangeListener { auth, user in
            // [START_EXCLUDE]
            // [END_EXCLUDE]
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // [START remove_auth_listener] 리스너 분리
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "PopupSegue" { // popup segue를 실행하기 전에 조건 확인
            // 세그를 실행하지 않음
            return false
        }
        // 다른 세그는 실행할 수 있도록 허용
        return true
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

class ResetPasswordDetailViewController: UIViewController {
    @IBOutlet weak var popupView: UIView!
    
    @IBAction func doCloseByTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: view)
        
        // 터치된 위치가 특정 뷰의 프레임 밖인지 확인
        if !popupView.frame.contains(location) {
            guard let presentingVC = presentingViewController as? UINavigationController else {
                dismiss(animated: true, completion: nil)
                return
            }
            
            self.dismiss(animated: true) {
                presentingVC.popViewController(animated: true)
            }
        }
    }
    
    @IBAction func doClose(_ sender: UIButton) {
        guard let presentingVC = presentingViewController as? UINavigationController else {
            dismiss(animated: true, completion: nil)
            return
        }
        
        self.dismiss(animated: true) {
            presentingVC.popViewController(animated: true)
        }
    }
}
