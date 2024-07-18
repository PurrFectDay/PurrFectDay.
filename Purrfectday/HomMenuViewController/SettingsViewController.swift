//
//  SettingsViewController.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/11.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import Toast_Swift


class SettingsViewController: UIViewController, UIGestureRecognizerDelegate {
    var window: UIWindow?
    var handle: AuthStateDidChangeListenerHandle?
    var ref: DatabaseReference!
    
    var user = Auth.auth().currentUser
    var email: String!
    
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var deleteAccountButton: UIButton!
    
    
    @IBAction func doResetPassword(_ sender: UIButton) {
        guard let email = Auth.auth().currentUser?.email else { return }
        AuthUtils.resetPassword(email: email) { success in
            if success {
                self.view.makeToast("비밀번호 재설정 이메일이 전송되었습니다.\n*메일이 확인되지 않을 경우 스팸함을 확인해주세요.", duration: 5.0, position: .top, title: "비밀번호 재설정")
            } else {
                self.view.makeToast("비밀번호 재설정 이메일이 전송에 실패하였습니다. 잠시 후 다시 시도해주세요.", duration: 5.0, position: .top, title: "비밀번호 재설정")
            }
        }
    }
    
    // 뒤로 가기
    @IBAction func goBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    // 로그아웃
    @IBAction func doSignOut(_ sender: Any) {
        AuthUtils.signOut() { success in
            if success {
                // 로그인 뷰로 이동
                // 새로운 뷰 컨트롤러들을 생성
                let signInVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignInView")
                // 네비게이션 컨트롤러의 스택을 새로운 뷰 컨트롤러 배열로 설정
                self.navigationController?.setViewControllers([signInVC], animated: true)
            } else {
                // Toast 메시지를 사용하여 로그아웃 실패 메시지를 화면 상단에 표시합니다.
                self.view.makeToast("로그아웃에 실패했습니다.", duration: 2.0, position: .top)
            }
        }
    }
    
    @IBAction func doDeleteAccount(_ sender: Any) {
        AlertUtils.showYesNoAlert(view: self, title: "알림", message: "계정의 모든 정보가 삭제되며 복구할 수 없습니다. 정말로 삭제하시겠습니까?🙀") { yes in
            if yes { // 사용자가 계정 삭제를 결정
                // 비밀번호로 본인 확인
                AlertUtils.showTextFieldAlert(view: self, title: "비밀번호 확인", message: "계정을 삭제하기 전에 비밀번호를 통해 본인 확인을 진행합니다.", placehold: "본인 확인을 위해서 비밀번호를 입력해주세요.", isPassword: true) { text in
                    if text == "" { // 비밀번호가 비어있음
                        self.view.makeToast("비밀번호를 입력해주세요.", duration: 3.0, position: .top)
                    }
                    else if text != nil { // 비밀번호가 입력됨
                        // 입력된 암호가 계정의 암호와 일치하는지 확인
                        AuthUtils.reAuth(email: self.email!, password: text ?? "") { success, error  in
                            if success { // 비밀번호 일치
                                // db에서 계정 정보 제거
                                self.ref.child("users").child(self.user!.uid).removeValue { (error, ref) in
                                    if let error = error { // 오류 발생, db에서 계정 정보 제거 실패
                                        NSLog("Error removing data from db: \(error.localizedDescription)")
                                        self.view.makeToast("오류로 계정 삭제에 실패했습니다. 잠시 후 다시 시도해주세요.😹", duration: 5.0, position: .top)
                                    } else { // 오류 없음, db에서 계정 정보 제거 성공
                                        NSLog("Data removed from db successfully")
                                        
                                        AuthUtils.deleteAccount() { success in // authentication에서 계정 삭제 시작
                                            if success { // 계정 최종 삭제 성공
                                                AlertUtils.showOkAlert(view: self, title: "알림", message: "계정이 삭제되었습니다.😿") { ok in
                                                    if ok { // 로그인 뷰로 이동
                                                        // 새로운 뷰 컨트롤러들을 생성
                                                        let signInVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SignInView")
                                                        // 네비게이션 컨트롤러의 스택을 새로운 뷰 컨트롤러 배열로 설정
                                                        self.navigationController?.setViewControllers([signInVC], animated: true)
                                                    }
                                                }
                                            } else { // 계정 최종 삭제 실패
                                                self.view.makeToast("계정 삭제에 실패했습니다. 잠시 후 다시 시도해주세요.😹", duration: 5.0, position: .top)
                                            }
                                        }
                                    }
                                }
                            } else { // 비밀번호 불일치
                                self.view.makeToast("비밀번호가 일치하지 않습니다.", duration: 3.0, position: .top)
                            }
                        }
                    }
                    else if text == nil {
                        // do nothing
                    }
                }
            } else { // 사용자가 계정 삭제 취소
                self.view.makeToast("감사합니다! PurrFectDay.와 함께 다시 힘차게 시작해봐요!😻", duration: 3.0, position: .top)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // [START auth_listener] 리스너 연결
        handle = Auth.auth().addStateDidChangeListener { auth, user in
          // [START_EXCLUDE]
          // [END_EXCLUDE]
        }
        ref = Database.database().reference()
        
        email = user?.email
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        // Do any additional setup after loading the view.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // [START remove_auth_listener] 리스너 분리
        Auth.auth().removeStateDidChangeListener(handle!)
        // [END remove_auth_listener]
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


class SettingSoundViewController: UIViewController {
    
    @IBOutlet weak var backgroundMusicSlider: UISlider!
    @IBOutlet weak var soundEffectSlider: UISlider!
    @IBOutlet weak var backgroundMusicValueLabel: UILabel!
    @IBOutlet weak var soundEffectValueLabel: UILabel!
    var backgroundMusicSliderView = UIImageView()
    var soundEffectSliderView = UIImageView()
    
    @IBAction func goBack(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func controlBackgroundMusic(_ sender: UISlider) {
        let value = round(sender.value)
        
        // 배경음 변경
        BackgroundMusicPlayer.shared.setVolume(value)
        
        // 화면에 표시
        backgroundMusicValueLabel.text = String(Int(value) * 10)
        
        // 값 저장
        BackgroundMusicPlayer.shared.saveInitialVolume(value)
    }
    
    @IBAction func controlSoundEffect(_ sender: UISlider) {
        let value = round(sender.value)
        
        // 배경음 변경
        SoundEffectPlayer.shared.setVolume(value)
        
        // 화면에 표시
        soundEffectValueLabel.text = String(Int(value * 10))
        
        // 값 저장
        SoundEffectPlayer.shared.saveInitialVolume(value)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // 슬라이더 배경 이미지 뷰 추가
        addSliderBackgroundView(for: self.backgroundMusicSlider)
        addSliderBackgroundView(for: self.soundEffectSlider)
        
        // 슬라이더 설정
        setupSlider(self.backgroundMusicSlider, backgroundView: backgroundMusicSliderView)
        setupSlider(self.soundEffectSlider, backgroundView: soundEffectSliderView)
        
        // 화면 초기 세팅
        let backgroundVolume = BackgroundMusicPlayer.shared.getInitialVolume()
        self.backgroundMusicSlider.setValue(backgroundVolume, animated: true)
        self.backgroundMusicValueLabel.text = String(Int(backgroundVolume * 10))
        
        let soundEffectVolume = SoundEffectPlayer.shared.getInitialVolume()
        self.soundEffectSlider.setValue(soundEffectVolume, animated: true)
        self.soundEffectValueLabel.text = String(Int(soundEffectVolume * 10))
        
        // 슬라이더 이미지 설정
        updateSliderBackground(for: Int(backgroundVolume), in: backgroundMusicSliderView)
        updateSliderBackground(for: Int(soundEffectVolume), in: soundEffectSliderView)
    }
    
    func addSliderBackgroundView(for slider: UISlider) {
        let backgroundView = UIImageView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: slider.trailingAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            backgroundView.heightAnchor.constraint(equalTo: slider.heightAnchor)
        ])
        
        if slider == self.backgroundMusicSlider {
            backgroundMusicSliderView = backgroundView
        } else if slider == soundEffectSlider {
            soundEffectSliderView = backgroundView
        }
    }
    
    func setupSlider(_ slider: UISlider, backgroundView: UIImageView) {
        slider.minimumValue = 0
        slider.maximumValue = 10
        slider.isContinuous = true
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        // Thumb과 Track 이미지를 투명하게 설정하여 슬라이더가 보이지 않도록 함
        slider.setThumbImage(UIImage(), for: .normal)
        slider.setMinimumTrackImage(UIImage(), for: .normal)
        slider.setMaximumTrackImage(UIImage(), for: .normal)
        
        // 슬라이더 배경 설정
        backgroundView.contentMode = .scaleAspectFit
        createSliderBackground(in: backgroundView)
    }
    
    @objc func sliderValueChanged(_ sender: UISlider) {
        let roundedValue = round(sender.value)
        print(roundedValue)
        
        sender.setValue(roundedValue, animated: false)
        updateSliderBackground(for: Int(roundedValue), in: sender == self.backgroundMusicSlider ? self.backgroundMusicSliderView : self.soundEffectSliderView)
    }
    
    func createSliderBackground(in backgroundView: UIImageView) {
        // 초기 배경 이미지 설정 (필요에 따라 변경)
        backgroundView.image = createBackgroundImage(filledSections: 0)
    }
    
    func updateSliderBackground(for value: Int, in backgroundView: UIImageView) {
        // 값에 따라 배경 이미지 업데이트
        backgroundView.image = createBackgroundImage(filledSections: value)
    }
    
    func createBackgroundImage(filledSections: Int) -> UIImage? {
        let numberOfSteps = 10
        let stepWidth: CGFloat = self.backgroundMusicSlider.frame.width / CGFloat(numberOfSteps) + 5
        let stepHeight: CGFloat = self.backgroundMusicSlider.frame.width / CGFloat(numberOfSteps) + 5

        let onImage = UIImage(named: "slider_fill")! // 켜진 칸 이미지
        let offImage = UIImage(named: "slider_empty")! // 꺼진 칸 이미지
        
        // 이미지 렌더러로 그림
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: stepWidth * CGFloat(numberOfSteps), height: stepHeight))
        let image = renderer.image { context in
            for i in 0..<numberOfSteps {
                let rect = CGRect(x: CGFloat(i) * stepWidth, y: 0, width: stepWidth, height: stepHeight)
                let image = i < filledSections ? onImage : offImage
                image.draw(in: rect)
            }
        }
        
        return image
    }
}
