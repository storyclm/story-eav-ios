//
//  ConfiguratorViewController.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 17.05.2021.
//

import UIKit

final class ConfiguratorViewController: UIViewController {

    @IBOutlet var textField: UITextView!
    @IBOutlet var saveButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.textField.alwaysBounceVertical = true

        self.updateSaveButtonState()
    }

    // MARK: - State

    private func updateSaveButtonState() {
        self.saveButton.isEnabled = self.textField.text.isEmpty == false
    }

    // MARK: - Actions

    @IBAction func saveButtonAction(_ sender: UIButton) {
        guard let script = self.textField.text, script.isEmpty == false else { return }
        (self.tabBarController as? TabBarController)?.addStoryConfigurator(script)
    }
}

extension ConfiguratorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        self.updateSaveButtonState()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.view.endEditing(true)
    }
}
