//
//  ScriptManager.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 14.05.2021.
//

import Foundation
import Alamofire
import Regex

final class ScriptManager {

    static private let storageFileName = "ScriptManager.json"

    struct Script: Codable {
        let script: String
        var version: String?
    }

    static let instance = ScriptManager()

    var currentScript: Script?

    private init() {
        self.loadFromStorage()
    }

    // MARK: - Storage

    private func loadFromStorage() {
        if Storage.fileExists(ScriptManager.storageFileName, in: Storage.Directory.documents) {
            self.currentScript = Storage.retrieve(ScriptManager.storageFileName, from: Storage.Directory.documents, as: Script.self)
        }
    }

    // MARK: - Api

    func downloadScript(completion: @escaping (Result<Script>) -> Void) {
        let injectStriptPath = "https://pastebin.com/raw/V5FfUV2m"
        guard let url = URL(string: injectStriptPath) else {
            let error = NSError(domain: "ScriptManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Ссылка на скрипт невалидна!"])
            completion(Result.failure(error))
            return
        }

        Alamofire.request(url).responseString { dataResult in
            switch dataResult.result {
            case let .success(script):
                var result: Script
                let revRegex = Regex("\\/\\/\\srev\\:(\\d+)")
                if let rev = script.split(separator: "\n").first, let matchResult = revRegex.firstMatch(in: String(rev)), let version = matchResult.captures.first {
                    result = Script(script: script, version: version)
                } else {
                    result = Script(script: script, version: nil)
                }

                self.currentScript = result
                Storage.store(result, to: Storage.Directory.documents, as: ScriptManager.storageFileName)

                completion(Result.success(result))
            case let .failure(error):
                completion(Result.failure(error))
            }
        }
    }
}
