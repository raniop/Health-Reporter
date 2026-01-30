//
//  ProfileFirestoreSync.swift
//  Health Reporter
//
//  שמירה/טעינה של תמונת פרופיל ב-Firestore + Storage.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

enum ProfileFirestoreSync {

    private static let usersCollection = "users"
    private static let fieldPhotoURL = "photoURL"
    private static let fieldDisplayName = "displayName"

    /// שומר שם תצוגה ב-Firestore.
    static func saveDisplayName(_ name: String, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion?(NSError(domain: "ProfileFirestoreSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }
        let db = Firestore.firestore()
        db.collection(usersCollection).document(uid).setData([fieldDisplayName: name], merge: true) { err in
            DispatchQueue.main.async { completion?(err) }
        }
    }

    /// טוען שם תצוגה מ-Firestore.
    static func fetchDisplayName(completion: @escaping (String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let db = Firestore.firestore()
        db.collection(usersCollection).document(uid).getDocument { snap, _ in
            let name = snap?.data()?[fieldDisplayName] as? String
            DispatchQueue.main.async { completion(name?.isEmpty == false ? name : nil) }
        }
    }

    /// שומר URL תמונת פרופיל ב-Firestore (מתאים ל-users/{uid}).
    static func savePhotoURL(_ url: String, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion?(NSError(domain: "ProfileFirestoreSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }
        let db = Firestore.firestore()
        db.collection(usersCollection).document(uid).setData([fieldPhotoURL: url], merge: true) { err in
            DispatchQueue.main.async { completion?(err) }
        }
    }

    /// טוען URL תמונת פרופיל מ-Firestore.
    static func fetchPhotoURL(completion: @escaping (String?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let db = Firestore.firestore()
        db.collection(usersCollection).document(uid).getDocument { snap, err in
            guard err == nil, let url = snap?.data()?[fieldPhotoURL] as? String, !url.isEmpty else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(url) }
        }
    }

    /// מעלה תמונה ל-Storage, מחזיר download URL. path: profile_photos/{uid}.jpg
    static func uploadProfileImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion(.failure(NSError(domain: "ProfileFirestoreSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized])))
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.75) else {
            completion(.failure(NSError(domain: "ProfileFirestoreSync", code: -2, userInfo: [NSLocalizedDescriptionKey: "sync.imageConversionError".localized])))
            return
        }
        let ref = Storage.storage().reference().child("profile_photos/\(uid).jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        ref.putData(data, metadata: meta) { _, err in
            if let e = err {
                DispatchQueue.main.async { completion(.failure(e)) }
                return
            }
            ref.downloadURL { url, err in
                if let e = err {
                    DispatchQueue.main.async { completion(.failure(e)) }
                    return
                }
                guard let u = url?.absoluteString else {
                    DispatchQueue.main.async { completion(.failure(NSError(domain: "ProfileFirestoreSync", code: -3, userInfo: [NSLocalizedDescriptionKey: "sync.noURLReceived".localized]))) }
                    return
                }
                DispatchQueue.main.async { completion(.success(u)) }
            }
        }
    }
}
