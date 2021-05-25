//
//  AppDelegate.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 26.04.2021.
//

import UIKit
import StoryContent

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.setupStoryContent()
        return true
    }

    private func setupStoryContent() {
        let propertyManager = AppPropertiesManager.instance

        SCLMAuthService.shared.setAuthEndpoint("https://staging-auth.storyclm.com")
        SCLMSyncService.shared.setApiEndpoint("https://stagingclmapi.azurewebsites.net")

        SCLMAuthService.shared.setClientId(propertyManager.storyContent.clientId)
        SCLMAuthService.shared.setClientSecret(propertyManager.storyContent.secret)
    }
}
