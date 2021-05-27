//
//  TabbarController.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 17.05.2021.
//

import UIKit
import StoryContent

final class TabBarController: UITabBarController {

    private var presentation: Presentation?

    func inject(presentation: Presentation) {
        self.presentation = presentation

        for viewController in self.viewControllers ?? [] {
            guard let presentationVC = viewController as? PresentationVC else { continue }

            presentationVC.inject(presentation: presentation)
        }
    }

    // MARK: - ViewControllers

    private var presentationViewController: PresentationVC? {
        return self.getViewController()
    }

    private var configuratorViewController: ConfiguratorViewController? {
        return self.getViewController()
    }

    private var logViewController: ConsoleLogTableController? {
        return self.getViewController()
    }

    private func getViewController<T>() -> T? {
        return self.viewControllers?.filter({ $0 is T }).first as? T
    }

    // MARK: - Logs

    func addLog(_ text: String) {
        self.logViewController?.addLogMessage(text)
    }

    func addStoryConfigurator(_ text: String) {
        self.presentationViewController?.addConfiguration(text)
    }

    func toConfigurator(_ config: [String: Any]?) {
        var text = "{}"
        if let config = config,
           let jsonData = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted]),
           let jsonText = String(data: jsonData, encoding: String.Encoding.utf8)
        {
            text = jsonText
        }
        if self.configuratorViewController?.isViewLoaded == false {
            self.configuratorViewController?.loadView()
        }
        self.configuratorViewController?.textField.text = text
        self.configuratorViewController?.view.setNeedsLayout()
    }
}
