//
//  PresentationInfoModel.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 26.05.2021.
//

import Foundation
import StoryContent

final class PresentationInfoModel: BaseJSReflectableModel {
    override var jsClassName: String {
        return "presentation"
    }

    override init() {
        fatalError("Unavaliable")
    }

    // MARK: - Properties

    let presentationId: String?
    let revision: Int?

    init(presentation: Presentation) {
        self.presentationId = presentation.presentationId?.stringValue
        self.revision = presentation.revision?.intValue
    }
}
