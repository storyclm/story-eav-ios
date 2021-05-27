//
//  SetPropModel.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 26.05.2021.
//

import Foundation

struct SetPropModel: Decodable {

    enum Types: String {
        case boolean
        case integer
        case float
        case string
        case null
    }

    let objectName: String
    let keyPath: String
    let type: String
    let value: Any?

    enum CodingKeys: String, CodingKey {
        case objectName
        case keyPath
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.objectName = try container.decode(String.self, forKey: .objectName)
        self.keyPath = try container.decode(String.self, forKey: .keyPath)
        self.type = try container.decode(String.self, forKey: .type)

        let eType = Types(rawValue: self.type)
        switch eType {
        case .boolean:
            self.value = try container.decode(Bool.self, forKey: .value)
        case .float:
            self.value = try container.decode(Double.self, forKey: .value)
        case .integer:
            self.value = try container.decode(Int.self, forKey: .value)
        case .string:
            self.value = try container.decode(String.self, forKey: .value)
        default:
            self.value = nil
        }
    }
}
