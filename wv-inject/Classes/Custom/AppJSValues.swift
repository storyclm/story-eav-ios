//
//  JavaScriptInterface.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 26.04.2021.
//

import Foundation

protocol PropertyReflectable {
    func propertyNames() -> [String]
}

extension PropertyReflectable {
    func propertyNames() -> [String] {
        return Mirror(reflecting: self).children.compactMap { $0.label }
    }

    func jsPropertyValue(for key: String) -> Any? {
        let mirror = Mirror(reflecting: self)
        let children = mirror.children
        let property = children.filter({ $0.label == key }).first
        guard let value = property?.value else {
            return nil
        }

        switch value {
        case Optional<Any>.some(let ivalue):
            if type(of: ivalue) == String.self {
                return "\"\(ivalue)\""
            } else {
                return ivalue
            }
        default:
            return nil
        }
    }
}

@objc class BaseJSReflectableModel: NSObject, PropertyReflectable {
    var jsClassName: String {
        return String(describing: type(of: self).self)
    }

    func asJavaScript() -> String {
        var propertyResult: [String] = []
        for propertyName in self.propertyNames() {
            let propertyValue = self.jsPropertyValue(for: propertyName) ?? "null"
            let propertyClass = "\"\(propertyName)\": \(propertyValue)"
            propertyResult.append(propertyClass)
        }

        let result = """
        \"\(self.jsClassName)\": {
            \(propertyResult.joined(separator: ",\n"))
        }
        """
        return result
    }
}
