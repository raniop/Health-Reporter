//
//  ProfileFirestoreSync.swift
//  Health Reporter
//
//  Save/load profile photo in Firestore + Storage.
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
    private static let fieldDisplayNameLower = "displayNameLower"

    /// Saves display name in Firestore (including lowercase version for search).
    static func saveDisplayName(_ name: String, completion: ((Error?) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion?(NSError(domain: "ProfileFirestoreSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }
        let db = Firestore.firestore()
        db.collection(usersCollection).document(uid).setData([
            fieldDisplayName: name,
            fieldDisplayNameLower: name.lowercased()
        ], merge: true) { err in
            DispatchQueue.main.async { completion?(err) }
        }
    }

    /// Loads display name from Firestore.
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

    /// Saves profile photo URL in Firestore (for users/{uid}).
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

    /// Loads profile photo URL from Firestore.
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

    /// Deletes all Firestore data for the current user (called before Firebase Auth deletion).
    static func deleteAllUserData(completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            completion(NSError(domain: "ProfileFirestoreSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "sync.noUserLoggedIn".localized]))
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection(usersCollection).document(uid)
        let group = DispatchGroup()
        var firstError: Error?

        let setError: (Error?) -> Void = { error in
            if let error = error, firstError == nil { firstError = error }
        }

        // Helper to delete all docs in a subcollection
        let deleteSubcollection: (CollectionReference) -> Void = { collectionRef in
            group.enter()
            collectionRef.getDocuments { snapshot, error in
                if let error = error { setError(error); group.leave(); return }
                guard let docs = snapshot?.documents, !docs.isEmpty else { group.leave(); return }
                let batch = db.batch()
                for doc in docs { batch.deleteDocument(doc.reference) }
                batch.commit { error in setError(error); group.leave() }
            }
        }

        // 1. Delete subcollections under users/{uid}
        deleteSubcollection(userRef.collection("friends"))
        deleteSubcollection(userRef.collection("following"))
        deleteSubcollection(userRef.collection("followers"))
        deleteSubcollection(userRef.collection("notifications"))

        // 2. Delete publicScores/{uid}
        group.enter()
        db.collection("publicScores").document(uid).delete { error in
            setError(error); group.leave()
        }

        // 3. Delete friend requests involving this user (from or to)
        for field in ["fromUid", "toUid"] {
            group.enter()
            db.collection("friendRequests").whereField(field, isEqualTo: uid).getDocuments { snapshot, error in
                if let error = error { setError(error); group.leave(); return }
                guard let docs = snapshot?.documents, !docs.isEmpty else { group.leave(); return }
                let batch = db.batch()
                for doc in docs { batch.deleteDocument(doc.reference) }
                batch.commit { error in setError(error); group.leave() }
            }
        }

        // 4. Delete follow requests involving this user
        for field in ["fromUid", "toUid"] {
            group.enter()
            db.collection("followRequests").whereField(field, isEqualTo: uid).getDocuments { snapshot, error in
                if let error = error { setError(error); group.leave(); return }
                guard let docs = snapshot?.documents, !docs.isEmpty else { group.leave(); return }
                let batch = db.batch()
                for doc in docs { batch.deleteDocument(doc.reference) }
                batch.commit { error in setError(error); group.leave() }
            }
        }

        // 5. Delete profile photo from Storage
        group.enter()
        Storage.storage().reference().child("profile_photos/\(uid).jpg").delete { error in
            // Ignore "object not found" errors
            if let error = error as NSError?, error.domain == StorageErrorDomain, error.code == StorageErrorCode.objectNotFound.rawValue {
                group.leave()
            } else {
                setError(error)
                group.leave()
            }
        }

        // 6. Delete the user document itself
        group.enter()
        userRef.delete { error in
            setError(error); group.leave()
        }

        group.notify(queue: .main) {
            completion(firstError)
        }
    }

    /// Uploads image to Storage, returns download URL. path: profile_photos/{uid}.jpg
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
