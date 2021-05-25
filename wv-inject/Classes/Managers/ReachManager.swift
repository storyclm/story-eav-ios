//
//  ReachManager.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 14.05.2021.
//

import Foundation
import Alamofire

final class ReachManager {

    static let reachStatusNotificationName = Notification.Name("ReachManager.ReachStatus.NotificationName")

    static let instance = ReachManager()

    private let reachabilityManager: NetworkReachabilityManager

    var currentStatus: NetworkReachabilityManager.NetworkReachabilityStatus {
        return self.reachabilityManager.networkReachabilityStatus
    }

    private init() {
        guard let manager = NetworkReachabilityManager() else {
            fatalError("NetworkReachabilityManager creation fail")
        }

        self.reachabilityManager = manager
        self.reachabilityManager.listener = { newStatus in
            self.postNewStatus()
        }
    }

    private func postNewStatus() {
        NotificationCenter.default.post(name: ReachManager.reachStatusNotificationName, object: self.currentStatus)
    }
}
