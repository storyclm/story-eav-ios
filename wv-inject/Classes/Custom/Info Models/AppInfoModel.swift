//
//  AppInfoModel.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 26.05.2021.
//

import Foundation

final class AppInfoModel: BaseJSReflectableModel {

    override var jsClassName: String {
        return "app"
    }

    // MARK: - Property

    let bundleId: String?
    let osVersion: String?
    let appName: String?
    let shortVersion: String?

    override init() {
        let info = Bundle.main.infoDictionary

        self.bundleId = info?["CFBundleIdentifier"] as? String
        self.osVersion = info?["DTPlatformVersion"] as? String
        self.appName = info?["CFBundleName"] as? String
        self.shortVersion = info?["CFBundleShortVersionString"] as? String

        super.init()
    }
}
