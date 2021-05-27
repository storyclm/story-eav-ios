//
//  CustomScriptStorage.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 26.05.2021.
//

import Foundation
import StoryContent

final class CustomScriptStorage {

    typealias StoryScriptType = [String: Any]

    static func defaultScript(with presentation: Presentation) -> String {
        let scheme = """
        "scheme": {
            "app": {
                "appMutable": false,
                "contentMutable": false
            },
            "user": {
                "appMutable": false,
                "contentMutable": false
            },
            "presentation": {
                "appMutable": false,
                "contentMutable": false
            },
            "questProgress": {
                "appMutable": true,
                "contentMutable": false
            },
            "debugAppState": {
                "appMutable": true,
                "contentMutable": true
            }
        }
        """

        let appInfo = AppInfoModel().asJavaScript()
        let presentationInfo = PresentationInfoModel(presentation: presentation).asJavaScript()
        let userInfo = UserInfoModel().asJavaScript()

        let template = [scheme, appInfo, presentationInfo, userInfo].joined(separator: ",\n")

        return """
        window._story = {
            \(template)
        };
        """
    }

    // MARK: - Properties

    private let presentation: Presentation
    private(set) var story: StoryScriptType = [:] {
        didSet {
            self.saveToStorage()
        }
    }

    // MARK: - Init

    init(with presentation: Presentation) {
        self.presentation = presentation
    }

    // MARK: - Script

    func initialScript() -> String {
        return self.loadFromStorage() ?? CustomScriptStorage.defaultScript(with: self.presentation)
    }

    private func storageFileName() -> String {
        let presentationId = self.presentation.presentationId?.stringValue ?? ""
        return "\(presentationId)-story.json"
    }

    private func loadFromStorage() -> String? {
        let fileName = self.storageFileName()

        guard Storage.fileExists(fileName, in: Storage.Directory.documents) else {
            return nil
        }
        return Storage.retrieve(fileName, from: Storage.Directory.documents, as: String.self)
    }

    private func saveToStorage() {
        let fileName = self.storageFileName()

        let result = """
        window._story =
            \(self.story.asJson())
        ;
        """
        Storage.store(result, to: Storage.Directory.documents, as: fileName)
    }

    // MARK: - Mutating

    func setStoryModel(_ model: StoryScriptType?) {
        self.story = model ?? [:]
    }

    func setPropModel(_ prop: SetPropModel) -> StoryScriptType {
        guard var object = self.story[prop.objectName] as? StoryScriptType else {
            return self.story
        }

        object[keyPath: KeyPath(prop.keyPath)] = prop.value
        self.story[prop.objectName] = object

        return self.story
    }

    func deleteStoryProp(_ prop: DeletePropModel) -> StoryScriptType {
        if prop.keyPath.isEmpty {
            self.story[prop.objectName] = nil
        } else if var object = self.story[prop.objectName] as? StoryScriptType {
            object[keyPath: KeyPath(prop.keyPath)] = nil
            self.story[prop.objectName] = object
        }

        return self.story
    }
}

extension CustomScriptStorage.StoryScriptType {

    func asJson() -> String {
        let defaultJson = "{}"

        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []) else {
            return defaultJson
        }

        return String(data: data, encoding: String.Encoding.utf8) ?? defaultJson
    }
}
