//
//  VerifyViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/12.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase


class VerifyViewController: UIViewController {
    var handle: AuthStateDidChangeListenerHandle?
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var verifyButton: UIButton!
    @IBOutlet weak var verifiedButton: UIButton!
    
    @IBAction func goBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func doVerify(_ sender: UIButton) { // 사용자의 이메일 주소로 인증 링크 전송
        self.verifyButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Change 2.0 to the desired number of seconds
            self.verifyButton.isEnabled = true
        }
        
        // 이메일 인증 요청
        AuthUtils.sendVerifyEmail(user: DatabaseUtils.shared.user!) { success in
            if success {
                // 이메일 전송 성공
                self.view.makeToast("인증 이메일이 전송되었습니다. 이메일을 확인하여 인증을 진행해주세요.", duration: 5.0, position: .top)
            } else {
                // 이메일 전송 실패
                self.view.makeToast("인증 이메일이 전송에 실패했습니다.", duration: 3.0, position: .top)
                return
            }
        }
    }
    
    @IBAction func isVerified(_ sender: UIButton) {
        self.verifiedButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Change 2.0 to the desired number of seconds
            self.verifiedButton.isEnabled = true
        }
        
        // 키보드 내리기
        self.view.endEditing(true)
        
        // 인증 여부 확인
        AuthUtils.isVerified() { success in
            if success { // 인증 성공
                // 계정 정보 db에 저장
                DatabaseUtils.shared.setUserData() { success in
                    if success {
                        NSLog("Email Data saved successfully")
                        BackgroundMusicPlayer.shared.saveInitialVolume(5.0)
                        SoundEffectPlayer.shared.saveInitialVolume(5.0)
                        
                        // 회원가입 프로세스 완료
                        AlertUtils.showOkAlert(view: self, title: "회원가입 완료", message: "인증되었습니다.") { ok in
                            // 프로필 뷰로 이동
                            // 새로운 뷰 컨트롤러들을 생성
                            let homeVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HomeView")
                            let profileVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ProfileView")
                            
                            // 네비게이션 컨트롤러의 스택을 새로운 뷰 컨트롤러 배열로 설정
                            self.navigationController?.setViewControllers([homeVC, profileVC], animated: true)
                        }
                    }
                    else {
                        self.view.makeToast("오류가 발생했습니다. 다시 시도해주세요.", duration: 3.0, position: .top)
                    }
                }
            } else {
                self.view.makeToast("인증이 진행되지 않았습니다.\n*인증 이메일이 확인되지 않는 경우 스팸 메일함을 확인해주세요.", duration: 3.0, position: .top)
            }
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        // [START auth_listener] 리스너 연결
        handle = Auth.auth().addStateDidChangeListener { auth, user in
          // [START_EXCLUDE]
          // [END_EXCLUDE]
        }
        
        // text field의 텍스트를 user 이메일로 바꾸기
        self.emailTextField.text = DatabaseUtils.shared.email
        
        self.navigationController?.isNavigationBarHidden = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // [START remove_auth_listener] 리스너 분리
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
        
        // 뷰 컨트롤러가 사라질 때 네비게이션바 나타내기
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "ProfileSegue" { // popup segue를 실행하기 전에 조건 확인
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
