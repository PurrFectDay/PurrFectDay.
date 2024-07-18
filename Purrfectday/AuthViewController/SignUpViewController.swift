//
//  SignUpViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/12.
//

import UIKit
import FirebaseAuth

class SignUpViewController: UIViewController {
    var handle: AuthStateDidChangeListenerHandle?
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var passwordConfirmTextField: UITextField!
    @IBOutlet weak var confirmButton: UIButton!
    
    
    @IBAction func goBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func doConfirm(_ sender: UIButton) {
        self.confirmButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Change 2.0 to the desired number of seconds
            self.confirmButton.isEnabled = true
        }
        
        // 키보드 내리기
        self.view.endEditing(true)
        
        // 입력값 확인
        // 이메일 필드가 비어 있을 경우
        guard let email = self.emailTextField.text, !email.isEmpty else {
            // 토스트 메시지 표시
            self.view.makeToast("이메일을 입력해주세요.", duration: 3.0, position: .top)
            return
        }
        // 비밀번호 필드가 비어 있을 경우
        guard let password = self.passwordTextField.text, !password.isEmpty else {
            // 토스트 메시지 표시
            self.view.makeToast("비밀번호를 입력해주세요.", duration: 3.0, position: .top)
            return
        }
        // 비밀번호 확인 필드가 비어 있을 경우
        guard let confirmPassword = self.passwordConfirmTextField.text, !confirmPassword.isEmpty else {
            // 토스트 메시지 표시
            self.view.makeToast("비밀번호 확인을 입력해주세요.", duration: 3.0, position: .top)
            return
        }
        // 이메일 형식 검증
        if AuthUtils.isValidEmail(email) {
            NSLog("valid email")
        } else {
            NSLog("not valid email")
            self.view.makeToast("유효하지 않은 이메일 형식입니다.", duration: 3.0, position: .top)
            return
        }
        
        // 비밀번호와 비밀번호 확인이 일치하지 않을 경우 경고
        guard password == confirmPassword else {
            // 토스트 메시지 표시
            self.view.makeToast("비밀번호가 일치하지 않습니다.", duration: 3.0, position: .top)
            return
        }
        
        // 비밀번호가 6자(영문 기준) 미만일 때
        guard password.count >= 6 else {
            // 토스트 메시지 표시
            self.view.makeToast("비밀번호는 6자(영문 기준) 이상을 입력해주세요.", duration: 3.0, position: .top)
            return
        }
        
        AuthUtils.signUp(email: email, password: password) { success, error in
            if success { // 계정 생성 성공
                // 인증 이메일 화면으로 이동
                self.performSegue(withIdentifier: "VerifySegue", sender: nil)
            } else { // 계정 생성 실패
                if error == nil { // 이미 회원가입을 완료한 사용자
                    AlertUtils.showOkAlert(view: self, title: "회원가입 실패", message: "이미 존재하는 이메일 계정입니다.") { ok in
                        if ok {
                            // 로그인 뷰로 이동
                            self.navigationController?.popToRootViewController(animated: true)
                        }
                    }
                } else {
                    self.view.makeToast("계정 생성에 실패했습니다.\n\(error!.localizedDescription)", duration: 3.0, position: .top)
                }
            }
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
    
    // 빈화면 터치 시 키보드 내리기
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    // 다음 화면 띄우기 전에 동작
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "VerifySegue" { // verify segue를 실행하기 전에 조건 확인
            // 세그를 실행하지 않음
            return false
        }
        // 다른 세그는 실행할 수 있도록 허용
        return true
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
