//
//  AlertUtils.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/13.
//

import Foundation
import UIKit

class AlertUtils {
    // 확인 알림
    static func showOkAlert(view: UIViewController, title: String, message: String, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "확인", style: .default) { _ in
            completion(true)
        }
        
        alert.addAction(okAction)
        view.present(alert, animated: true, completion: nil)
    }
    
    static func showYesNoAlert(view: UIViewController, title: String, message: String, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "확인", style: .default) { _ in
            completion(true)
        }
        let noAction = UIAlertAction(title: "취소", style: .destructive) { _ in
            completion(false)
        }
        
        alert.addAction(yesAction)
        alert.addAction(noAction)
        view.present(alert, animated: true, completion: nil)
    }
    
    // 텍스트 필드가 있는 알림창
    static func showTextFieldAlert(view: UIViewController, title: String, message: String, placehold: String, isPassword: Bool, completion: @escaping (String?) -> Void) {
        // 알림창
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        // 확인 버튼
        let okAction = UIAlertAction(title: "확인", style: .default) { _ in
            let text = alert.textFields![0].text! // 텍스트 필드의 값을 비밀번호로 저장
            guard text.isEmpty else { // 비밀번호가 비어있지 않으면
                completion(text) // 비밀번호 전달
                return
            }
            completion("") // 비어있으면 "" 전달
        }
        
        let cancelAction = UIAlertAction(title: "취소", style: .destructive) { _ in
            completion(nil)
        }
        
        // 텍스트 필드 알림창에 추가
        alert.addTextField(configurationHandler:) { textField in
            textField.isSecureTextEntry = isPassword // 비밀번호 마스킹
            textField.placeholder = placehold
        }
        // 확인 버튼 알림창에 추가
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        view.present(alert, animated: true, completion: nil)
    }
}
