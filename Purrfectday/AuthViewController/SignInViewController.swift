//
//  SignInViewControlloer.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/11.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import Toast_Swift

class SignInViewControlloer: UIViewController, UINavigationControllerDelegate {
    var handle: AuthStateDidChangeListenerHandle?
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var signInButton: UIButton!
    
    
    // 로그인하기
    @IBAction func doSignIn(_ sender: Any) {
        self.signInButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Change 2.0 to the desired number of seconds
            self.signInButton.isEnabled = true
        }
        
        // 이메일 또는 비밀번호가 비어있는 경우에는 로그인을 시도하지 않고 사용자에게 알림
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            self.view.makeToast("이메일과 비밀번호를 입력하세요.", duration: 2.0, position: .top)
            
            return
        }
        
        // 로그인 시작
        AuthUtils.signIn(email: email, password: password) { success, error in
            if success { // 로그인 성공 시
                DatabaseUtils.shared.initializeData(for: Auth.auth().currentUser, completion: { })
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // 홈 뷰로 이동
                    let homeVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HomeView")
                    self.navigationController!.setViewControllers([homeVC], animated: true)
                }
                
                // db에 계정 정보가 존재하지 않는 경우 db에 초기 설정 저장
//                DatabaseUtils.shared.initUserData() {  }
            } else { // 로그인 실패 시
                if error == nil { // 인증되지 않은 사용자
                    // 알림창
                    AlertUtils.showOkAlert(view: self, title: "로그인 실패", message: "아직 인증되지 않은 사용자입니다. 이메일 인증을 진행해주세요.") { ok in
                        if ok {
                            // 인증 뷰로 이동
                            // 스토리보드에서 "id"라는 식별자를 가진 뷰 컨트롤러 인스턴스를 생성
                            let verifyVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "VerifyView")
                            // 네비게이션 컨트롤러에 새로운 뷰 컨트롤러 푸시
                            self.navigationController?.pushViewController(verifyVC, animated: true)
                        }
                    }
                } else { // 로그인 실패 메시지: 존재하지 않는 사용자, 옳지 않은 아이디 또는 비밀번호
                    self.view.makeToast("로그인에 실패했습니다.\n\(error!.localizedDescription)", duration: 2.0, position: .top)
                }
            }
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        BackgroundMusicPlayer.shared.stop()
        
        // [START auth_listener] 리스너 연결
        handle = Auth.auth().addStateDidChangeListener { auth, user in
            // [START_EXCLUDE]
            // [END_EXCLUDE]
        }
        
        DatabaseUtils.shared.initializeData(for: Auth.auth().currentUser, completion: {})
        
        
        // 뷰 컨트롤러가 나타날 때 네비게이션 바 숨기기
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 키보드 내리기
        self.view.endEditing(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        DatabaseUtils.shared.initializeData(for: Auth.auth().currentUser, completion: {})
        
        // [START remove_auth_listener] 리스너 분리
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
        
        // 뷰 컨트롤러가 사라질 때 네비게이션바 나타내기
        navigationController?.setNavigationBarHidden(false, animated: true)
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
