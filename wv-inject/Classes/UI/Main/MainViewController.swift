//
//  MainViewController.swift
//  wv-inject
//
//  Created by Sergey Ryazanov on 14.05.2021.
//

import UIKit
import Alamofire
import StoryContent

final class MainViewController: UIViewController {

    @IBOutlet var reachValueLabel: UILabel!
    @IBOutlet var scriptValueLabel: UILabel!
    @IBOutlet var presentationValueLabel: UILabel!
    @IBOutlet var authValueLabel: UILabel!

    @IBOutlet var scriptDownloadButton: UIButton!
    @IBOutlet var presentationDownloadButton: UIButton!
    @IBOutlet var presentationOpenButton: UIButton!

    private var seguePresentation: Presentation?

    override func viewDidLoad() {
        self.presentationOpenButton.isEnabled = false

        NotificationCenter.default.addObserver(self, selector: #selector(reachStatus(notification:)), name: ReachManager.reachStatusNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(authChange(notification:)), name: PresentationManager.authChangeNotificationName, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateStates()
    }

    // MARK: - State

    private func updateStates() {
        self.updateReachState()
        self.updateScriptState()
        self.updatePresentationState()
    }

    private func updateReachState() {
        let reachabilityStatus = ReachManager.instance.currentStatus

        var result = "Неизвестно"

        switch reachabilityStatus {
        case .notReachable:
            result = "Не доступен"
        case let .reachable(type):
            result = type == .wwan ? "wwan" : "WiFi"
        default:
            break
        }
        self.reachValueLabel.text = result
    }

    private func updateScriptState() {
        var result = "Неизвестно"
        if let scriptModel = ScriptManager.instance.currentScript {
            result = "Загружен (rev: \(scriptModel.version ?? "?"))"
        } else {
            result = "Не загружен"
        }

        self.scriptValueLabel.text = result
    }

    private func updateAuthState() {
        var result = "Неизвестно"

        if let authResult = PresentationManager.instance.currentAuthResult {
            result = authResult ? "Успех" : "Ошибка"
        }

        self.authValueLabel.text = result
    }

    private func updatePresentationState() {
        PresentationManager.instance.getTestPresentation { resultModel in
            var result = "Неизвестно"
            var rev = "?"
            switch resultModel {
            case let .success(presentation):
                self.presentationDownloadButton.isEnabled = true
                self.presentationOpenButton.isEnabled = false

                if presentation.isSyncReady() {
                    result = "Готова к синхронизации"
                } else if presentation.isSyncWait() {
                    result = "Ожидает синхронизации"
                } else if presentation.isUpdateAvailable() {
                    result = "Есть обновление"
                    self.presentationOpenButton.isEnabled = true
                } else if presentation.isSyncNow() {
                    result = "Обновляется"
                } else if presentation.isSyncDone() {
                    result = "Обновлена"
                    self.presentationOpenButton.isEnabled = true
                }
                rev = presentation.contentPackage?.revision?.stringValue ?? "?"
            case let .failure(error):
                self.presentationDownloadButton.isEnabled = false
                print("getTestPresentation error: \(error)")
            }

            DispatchQueue.main.async {
                self.presentationValueLabel.text = "\(result) (rev: \(rev))"
            }
        }
    }

    // MARK: - Actions

    @IBAction func scriptDownloadAction(_ sender: UIButton) {
        self.scriptValueLabel.text = "Загрузка..."
        sender.isEnabled = false

        ScriptManager.instance.downloadScript { result in
            self.updateScriptState()
            sender.isEnabled = true

            if case let .failure(error) = result {
                self.showErrorAlert(error)
            }
        }
    }

    @IBAction func authAction(_ sender: UIButton) {
        sender.isEnabled = false
        self.authValueLabel.text = "Авторизация..."

        PresentationManager.instance.tryAuth { error in
            sender.isEnabled = true
        }
    }

    @IBAction func presentationDownloadAction(_ sender: UIButton) {
        sender.isEnabled = false

        let label = self.presentationValueLabel
        label?.text = "Загрузка..."

        PresentationManager.instance.downloadPresentation { downloadError in
            sender.isEnabled = true
            self.updatePresentationState()
        } progressHandler: { progress in
            DispatchQueue.main.async {
                let progressStatus = "\(progress.localizedDescription ?? "Unknown") - \(progress.fractionCompleted)"
                label?.text = progressStatus
            }
        }
    }

    @IBAction func presentationOpenAction(_ sender: UIButton) {
        sender.isEnabled = false

        PresentationManager.instance.getTestPresentation { result in
            sender.isEnabled = true

            if case let .success(presentation) = result {
                self.seguePresentation = presentation
                self.performSegue(withIdentifier: "PresentationSegue", sender: self)
            }
        }
    }

    // MARK: - Segue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let presentationVC = segue.destination as? TabBarController, let presentation = self.seguePresentation else { return }
        presentationVC.inject(presentation: presentation)
    }

    // MARK: - Notifications

    @objc private func reachStatus(notification: Notification) {
        self.updateReachState()
    }

    @objc private func authChange(notification: Notification) {
        self.updateAuthState()
        self.updatePresentationState()
    }

    // MARK: - Alert

    private func showErrorAlert(_ error: Error) {
        let alert = UIAlertController(title: "Ошибка", message: error.localizedDescription, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true)
    }
}
