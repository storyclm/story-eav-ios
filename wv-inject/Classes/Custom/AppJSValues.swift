//
//  JavaScriptInterface.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 26.04.2021.
//

import Foundation
import Runtime

protocol PropertyReflectable {
    var classTypeInfo: TypeInfo? { get }
    func propertyNames() -> [String]
}

extension PropertyReflectable {
    var classTypeInfo: TypeInfo? {
        let iClass = type(of: self).self
        return try? typeInfo(of: iClass)
    }

    func propertyNames() -> [String] {
        return Mirror(reflecting: self).children.compactMap { $0.label }
    }

    func jsPropertyValue(for key: String) -> Any? {
        let info = self.classTypeInfo
        let property = try? info?.property(named: key)

        let value = try? property?.get(from: self)
        if property?.type == String.self {
            return "\'\(value ?? "")\'"
        } else {
            return value
        }
    }
}

@objc class BaseJSReflectableModel: NSObject, PropertyReflectable {
    var className: String {
        return String(describing: type(of: self).self)
    }

    func asJavaScript() -> String {
        var propertyResult: [String] = []
        for propertyName in self.propertyNames() {
            let propertyClass = "\(propertyName): \(self.jsPropertyValue(for: propertyName) ?? "")"
            propertyResult.append(propertyClass)
        }

        let result = """
        \(self.className): {
            \(propertyResult.joined(separator: ",\n"))
        }
        """
        return result
    }
}
