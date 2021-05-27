//
//  UserInfoModel.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 26.05.2021.
//

import Foundation
import StoryID

final class UserInfoModel: BaseJSReflectableModel {

    override var jsClassName: String {
        return "user"
    }

    // MARK: - Properties

    let phone: String?

    override init() {
        self.phone = SIDPersonalDataService.instance.profile.profile()?.phone
        super.init()
    }
}
