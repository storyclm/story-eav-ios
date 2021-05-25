//
//  PresentationManager.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 14.05.2021.
//

import Foundation
import StoryContent

final class PresentationManager {

    static let authChangeNotificationName = Notification.Name("PresentationManager.AuthChange.NotificationName")

    static let instance = PresentationManager()

    var currentAuthResult: Bool? {
        didSet {
            NotificationCenter.default.post(name: PresentationManager.authChangeNotificationName, object: nil)
        }
    }

    private init() {
        self.tryAuth()
    }

    func tryAuth(completion: ((Error?) -> Void)? = nil) {
        self.auth { authError in
            if let error = authError {
                print("[PresentationManager] Auth error: \(error)")
                self.currentAuthResult = false
                completion?(error)
            } else {
                self.sync { syncError in
                    if let error = syncError {
                        print("[PresentationManager] Sync error: \(error)")
                        self.currentAuthResult = false
                        completion?(error)
                    } else {
                        self.currentAuthResult = true
                        completion?(nil)
                    }
                }
            }
        }
    }

    // MARK: - APIs

    private func auth(completion: @escaping (Error?) -> Void) {
        SCLMAuthService.shared.authAsService {
            print("Auth success")
            completion(nil)
        } failure: { error in
            print("Auth error: \(error)")
            completion(error)
        }
    }

    private func sync(completion: @escaping (Error?) -> Void) {
        SCLMSyncManager.shared.synchronizeClients { error in
            completion(error)
        }
    }

    func getTestPresentation(completion: @escaping (Result<Presentation, Error>) -> Void) {
        let frc = SCLMSyncManager.shared.fetchedResultsController
        do {
            try frc.performFetch()
            if let presentations = frc.fetchedObjects as? [Presentation], let testPresentation = presentations.filter({ $0.presentationId == 209 }).first {
                completion(Result.success(testPresentation))
            } else {
                let error = NSError(domain: "PresentationManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Презентация отсутствует"])
                completion(Result.failure(error))
            }
        } catch {
            completion(Result.failure(error))
        }
    }

    func downloadPresentation(completion: @escaping (Error?) -> Void, progressHandler: ((Progress) -> Void)? = nil) {
        self.getTestPresentation { getPresentationResult in
            switch getPresentationResult {
            case let .success(presentation):
                SCLMSyncManager.shared.synchronizePresentation(presentation) { syncError in
                    completion(syncError)
                } progressHandler: { progress in
                    progressHandler?(progress)
                } psnHandler: { psn in
                    // Do nothing
                }
            case let .failure(error):
                completion(error)
            }
        }
    }
}
