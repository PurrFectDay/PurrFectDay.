//
//  IntroViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/14.
//

import UIKit
import SwiftyGif
import FirebaseAuth

class IntroViewController: UIViewController {
    var handle: AuthStateDidChangeListenerHandle?
    var isLoggedIn: Bool?
    
    @IBOutlet weak var introImage: UIImageView!
    
    override func viewWillAppear(_ animated: Bool) {
        // [START auth_listener] 리스너 연결
        handle = Auth.auth().addStateDidChangeListener { auth, user in
            // [START_EXCLUDE]
            // [END_EXCLUDE]
        }
        
        // Do any additional setup after loading the view.
        do {
            let gif = try UIImage(gifName: "shotterIntro.gif")
            self.introImage.setGifImage(gif, loopCount: 1) // GIF를 한 번만 재생하도록 설정
            self.introImage.delegate = self // GIF가 재생될 때 호출할 delegate 설정
        } catch {
            NSLog("cannot play intro view")
        }
        
        BackgroundMusicPlayer.shared.play(fileName: "Kitten meows")
        
        // 앱이 백그라운드로 전환될 때 배경음악 일시 중지하는 옵저버 추가
        NotificationCenter.default.addObserver(self, selector: #selector(pauseSong), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // 앱이 포그라운드로 다시 들어올 때 배경음악 재생하는 옵저버 추가
        NotificationCenter.default.addObserver(self, selector: #selector(playSong), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        DatabaseUtils.shared.initializeData(for: Auth.auth().currentUser ?? nil, completion: {})
    }
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // [START remove_auth_listener] 리스너 분리
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
        
        // 현재 재생 중인 음악 멈추기
        BackgroundMusicPlayer.shared.stop()
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

// GIF가 재생될 때 호출되는 메서드
extension IntroViewController: SwiftyGifDelegate {
    func gifDidStop(sender: UIImageView) {
        
        // 자동 로그인
        // 조건에 따라 초기 뷰 설정
        if Auth.auth().currentUser != nil { // 사용자가 로그인한 경우
            AuthUtils.isVerified() { success in // 인증된 사용자인 경우
                if success { // 사용자가 로그인한 경우
                    // 홈 뷰로 이동
                    NSLog("already logged in go to main view")
                    
                    // 새로운 뷰 컨트롤러들을 생성
                    let homeVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HomeView")
                    // 네비게이션 컨트롤러의 스택을 새로운 뷰 컨트롤러 배열로 설정
                    self.navigationController?.setViewControllers([homeVC], animated: true)
                    
                }
                else {  // 인증되지 않은 사용자인 경우
                    // 인증 화면으로 이동
                    // 현재 네비게이션 스택의 뷰 컨트롤러들을 가져옴
                    var viewControllers: [UIViewController] = []
                    
                    // 새로운 뷰 컨트롤러들을 생성합니다.
                    let signInVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignInView")
                    let verifyVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "VerifyView")
                    
                    // 생성한 뷰 컨트롤러들을 네비게이션 스택에 추가
                    viewControllers.append(signInVC)
                    viewControllers.append(verifyVC)
                    
                    // 네비게이션 컨트롤러의 스택을 새로운 뷰 컨트롤러 배열로 설정
                    self.navigationController?.setViewControllers(viewControllers, animated: true)
                }
            }
        } else { // 사용자가 로그인하지 않은 경우
            // 로그인 뷰로 이동
            NSLog("needed login in go to sign in view")
            // 새로운 뷰 컨트롤러들을 생성
            let signInView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignInView")
            // 네비게이션 컨트롤러의 스택을 새로운 뷰 컨트롤러 배열로 설정
            self.navigationController?.setViewControllers([signInView], animated: true)
        }
    }
}
