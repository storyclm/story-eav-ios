//
//  DeletePropModel.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 27.05.2021.
//

import Foundation

struct DeletePropModel: Decodable {
    
    let objectName: String
    let keyPath: String
}
