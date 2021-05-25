//
//  AppPropertiesManager.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 24.05.2021.
//

import Foundation

final class AppPropertiesManager {

    struct Credential {
        let secret: String
        let clientId: String
    }

    static let instance = AppPropertiesManager()

    private(set) var rawProperties: [String: AnyObject]

    let storyContent: Credential
    let storyId: Credential

    private init() {
        guard let prop = AppPropertiesManager.readPropertyList() else {
            fatalError("[AppPropertiesManager] AppProperties is missed or has wrong format")
        }
        guard let contentSecret = prop["STORY_CONTENT_SECRET"] as? String, let contentClientId = prop["STORY_CONTENT_CLIENT_ID"] as? String else {
            fatalError("[AppPropertiesManager] Story content properties is missed")
        }

        guard let idSecret = prop["STORY_ID_CLIENT_SECRET"] as? String, let idClientId = prop["STORY_ID_CLIENT_ID"] as? String else {
            fatalError("[AppPropertiesManager] StoryID properties is missed")
        }

        self.storyContent = Credential(secret: contentSecret, clientId: contentClientId)
        self.storyId = Credential(secret: idSecret, clientId: idClientId)
        self.rawProperties = prop
    }

    private static func readPropertyList() -> [String: AnyObject]? {
        guard let path = Bundle.main.path(forResource: "AppProperties", ofType: "plist") else { return nil }
        return NSDictionary(contentsOfFile: path) as? [String: AnyObject]
    }
}
