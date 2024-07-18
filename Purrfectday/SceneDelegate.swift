//
//  SceneDelegate.swift
//  Purrfectday
//
//  
//

import UIKit
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }
    
//    func switchRoot(id: String) {
//        // Main 스토리보드 로드
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        // 스토리보드에서 "id"라는 식별자를 가진 뷰 컨트롤러 인스턴스를 생성
//        let vc = storyboard.instantiateViewController(withIdentifier: id)
//        // vc를 루트 뷰 컨트롤러로 하는 새로운 UINavigationController 인스턴스를 생성
//        let nvc = UINavigationController(rootViewController: vc)
//        
//        // window의 루트 뷰 컨트롤러를 새로 생성한 네비게이션 컨트롤러 nvc로 설정
//        self.window?.rootViewController = nvc
//        // 변경된 루트 뷰 컨트롤러를 화면에 표시하고, 키 윈도우로 만듦
//        window?.makeKeyAndVisible()
//    }
//    ex. 사용 방법
//    let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate
//    sceneDelegate?.switchRoot(id: "HomeView")

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }


}

