//
//  AuthUtils.swift
//  Purrfectday
//
//  Created by 김정현 on 2024/04/13.
//

import Foundation
import FirebaseAuth


class AuthUtils {
    // 이메일 형식 검증
    static func isValidEmail(_ email: String) -> Bool {
        // 이메일 형식을 나타내는 정규표현식
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func signIn(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        // 로그인 시작
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            // 로그인 실패
            guard let _ = authResult?.user, error == nil else {
                NSLog("login failed")
                completion(false, error)
                return
            }
            // 로그인 성공: 존재하는 사용자, 알맞은 아이디와 비밀번호
            AuthUtils.isVerified() { success in // 인증 여부 확인
                if success { // 인증된 사용자, 로그인 성공
                    NSLog("login successed")
                    completion(true, nil)
                } else { // 인증되지 않은 사용자, 로그인 실패로 간주
                    completion(false, nil)
                }
            }
        }
    }

    static func signOut(completion: @escaping (Bool) -> Void) {
        // [START signout]
        let firebaseAuth = Auth.auth() // Firebase의 인증(Auth) 객체를 가져옵니다.
        do {
            // Firebase의 signOut() 메서드를 사용하여 사용자를 로그아웃합니다.
            try firebaseAuth.signOut()
            // 로그아웃 성공
            NSLog("logout successed")
            completion(true)
        } catch let signOutError as NSError { // 로그아웃 실패
            NSLog("logout failed: %@", signOutError)
            completion(false)
        }
        // [END signout]
    }
    
    // 회원가입
    static func signUp(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        // 이메일과 비밀번호로 유저 생성
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if error != nil { // 유저 생성 실패
                if error?.localizedDescription == "The email address is already in use by another account." { // 이미 존재하는 유저
                    NSLog("create user failed: \(String(describing: error?.localizedDescription))")
                    completion(false, nil)
                }
                NSLog("create user failed: \(String(describing: error?.localizedDescription))")
                completion(false, error)
            }
            // 유저 생성 성공
            NSLog("user create successed")
            completion(true, nil)
        }
    }
    
    // 이메일 인증 요청
    static func sendVerifyEmail(user: User, completion: @escaping (Bool) -> Void) {
        user.sendEmailVerification { error in
            if let error = error { // 인증 이메일 전송 실패
                NSLog("Error sending verification email: \(error.localizedDescription)")
                completion(false) // 실패한 경우 false를 전달
            }
            // 인증 이메일 전송 성공
            NSLog("Verification email sent to \(String(describing: user.email))")
            completion(true) // 성공한 경우 true를 전달
        }
    }
    
    // 사용자가 인증되었는지 확인
    static func isVerified(completion: @escaping (Bool) -> Void) {
        // 현재 유저 정보 확인
        Auth.auth().currentUser?.reload(completion: { error in
            if let error = error { // 에러 발생
                NSLog("Error reloading user: \(error.localizedDescription)")
                completion(false) // 실패한 경우 false를 전달
            }
            
            // 해당 계정이 인증되었는지 확인
            if let user = Auth.auth().currentUser, user.isEmailVerified {
                NSLog("User is verified.")
                completion(true) // 성공한 경우 true를 전달
            } else { // 실패한 경우 false를 전달
                NSLog("User is not verified.")
                completion(false) // 실패한 경우 false를 전달
            }
            
            
        })
    }
    
    // 비밀번호 업데이트
    static func updatePassword (email: String, password: String, completion: @escaping (Bool) -> Void) {
        AuthUtils.reAuth(email: email, password: password) { success, error  in
            if success {
                Auth.auth().currentUser?.updatePassword(to: password) { updateError in
                    if let updateError = updateError {
                        NSLog("Update password failed: \(updateError.localizedDescription)")
                        completion(false)
                    } else {
                        NSLog("Update password success")
                        completion(true)
                    }
                }
            } else {
                NSLog("Update password failed: \(String(describing: error?.localizedDescription))")
                completion(false)
            }
        }
        
        
    }
    
    // 비밀번호 재설정 이메일 전송
    static func resetPassword (email: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error { // 비밀번호 재설정 이메일 전송 실패
                NSLog("failed password reset email: \(error.localizedDescription)")
                completion(false) // 실패한 경우 false를 전달
            } else { // 비밀번호 재설정 이메일 전송 성공
                NSLog("sended password reset email")
                completion(true) // 성공한 경우 true를 전달
            }
        }
    }
    
    // 사용자 재인증
    // 계정 삭제, 기본 이메일 주소 설정, 비밀번호 변경과 같이 보안에 민감한 작업을 하려면 사용자가 최근에 로그인한 적이 있어야 합니다. 이런 작업을 할 때 사용자가 너무 오래 전에 로그인했다면 FIRAuthErrorCodeCredentialTooOld 오류가 발생하면서 작업이 실패합니다. 이때에는 사용자에게 새로운 로그인 인증 정보를 받은 다음 이 정보를 reauthenticate에 전달하여 사용자를 재인증해야 합니다.
    // 사용자 재인증
    static func reAuth(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        Auth.auth().currentUser?.reauthenticate(with: credential) { result, error in
            if let error = error {
                NSLog("Failed to reauthenticate: \(error.localizedDescription)")
                completion(false, error)
            } else {
                NSLog("User reauthenticated.")
                completion(true, nil)
            }
        }
    }
    
    static func deleteAccount(completion: @escaping (Bool) -> Void) {
        let user = Auth.auth().currentUser

        user?.delete { error in
          if let _ = error {
            // An error happened.
              completion(false)
          } else {
            // Account deleted.
              completion(true)
          }
        }
    }
}
