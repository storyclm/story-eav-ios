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
        return self.viewControllers?.filter({ $0 is PresentationVC }).first as? PresentationVC
    }

    private var logViewController: ConsoleLogTableController? {
        return self.viewControllers?.filter({ $0 is ConsoleLogTableController }).first as? ConsoleLogTableController
    }

    // MARK: - Logs

    func addLog(_ text: String) {
        self.logViewController?.addLogMessage(text)
    }

    func addStoryConfigurator(_ text: String) {
        let js = """
        window._story = \(text)
        _onStoryChange();
        """

        self.presentationViewController?.webView.evaluateJavaScript(js, completionHandler: { frame, error in
            if let error = error {
                print("Error: \(error)")
            } else {
                print("Frame: \(String(describing: frame))")
            }
        })
    }
}
