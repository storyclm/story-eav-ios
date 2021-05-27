//
//  PresentationVC.swift
//  iPharmocist ASNA
//
//  Created by Александр Смородов on 09/09/2019.
//  Copyright © 2019 Platfomni. All rights reserved.
//

import UIKit
import WebKit
import StoryContent
import CoreLocation

protocol PresentationVCDelegate: AnyObject {
    func PresentationVCWillClose()
}

class PresentationVC: UIViewController,
    WKNavigationDelegate,
    UIGestureRecognizerDelegate,
    SCLMBridgeProtocol,
    SCLMBridgeMediaFilesModuleProtocol,
    SCLMBridgeBaseModuleProtocol,
    SCLMBridgeUIModuleProtocol,
    SCLMBridgeCustomEventsModuleProtocol,
    SCLMBridgePresentationModuleProtocol,
    SCLMBridgeSessionsModuleProtocol,
    SCLMBridgeMapModuleProtocol
{

    enum MessageHandler: String, CaseIterable {
        case logHandler
        case setStoryProp
        case deleteStoryProp
    }

    weak var delegate: PresentationVCDelegate?

    @IBOutlet var webView: SCLMWebView!
    @IBOutlet var tapGesture: UITapGestureRecognizer!

    private var bridge: SCLMBridge?
    private var currentPresentation: Presentation!

    private var currentSlide: Slide!

    private var navigationMethod: String?
    private var slideStartTime: CFTimeInterval = 0
    private var slideInactiveTime: CFTimeInterval = 0

    private var previousSlide: Slide?
    private var nextSlide: Slide?
    private var backForwardList = [String]()
    private var backForwardPresList = [Presentation]()
    private var navigationData = ["": ""]

    private var mediaPlaybackRequiresUserAction: WKAudiovisualMediaTypes = []
    private var controlsTimer: Timer?
    private var presentationTimer: Timer?
    private var isControlsHidden = false

    private var scriptStorage: CustomScriptStorage!

    deinit {
        print("PresentationVC deinit")
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }

    override var shouldAutorotate: Bool {
        return true
    }

    // MARK: -

    class func get() -> PresentationVC {
        let sb = UIStoryboard(name: "Library", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "PresentationVC") as! PresentationVC
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addObservers()

        UserDefaults.standard.removeObject(forKey: "applicationWillResignActiveStartTime")

        guard currentPresentation != nil else {
            fatalError("presentation should be settled befor viewDidLoad")
        }

        bridge = SCLMBridge(presenter: webView, presentation: currentPresentation, delegate: self)

        self.tapGesture.delegate = self

        self.webView.navigationDelegate = self
        self.webView.scrollView.isScrollEnabled = false

        self.addUserScripts()

        setupWebViewConfiguration()
        setupUI()

        createOrRestoreSessionIfNeed()

        if let startUpSlide = currentPresentation.startUpSlide() {
            currentSlide = startUpSlide
            slideStartTime = CACurrentMediaTime()
            slideInactiveTime = 0
            navigationMethod = "in"
            loadSlide(startUpSlide)
        }

        // BackForwardLists
        if let presentation = currentPresentation {
            backForwardPresList.append(presentation)
        }
        if let slideName = currentSlide.name {
            backForwardList.append(slideName)
        }
    }

    private func addUserScripts() {

        let userContentController = self.webView.configuration.userContentController

        // Logger
        let loggerScript = "function captureLog(msg) { window.webkit.messageHandlers.logHandler.postMessage(msg); } window.console.log = captureLog;"
        let userScript = WKUserScript(source: loggerScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(userScript)

        // Handler
        for handler in PresentationVC.MessageHandler.allCases {
            userContentController.add(self, name: handler.rawValue)
        }

        // Custom script
        if let loadedScript = ScriptManager.instance.currentScript?.script {
            let script = WKUserScript(source: loadedScript, injectionTime: WKUserScriptInjectionTime.atDocumentStart, forMainFrameOnly: true)
            userContentController.addUserScript(script)
        }

        // StoryTemplate
        let storyTemplate = self.scriptStorage.initialScript()
        self.webView.evaluateJavaScript(storyTemplate) { frame, error in
            if let error = error {
                print("Error: \(error)")
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    // MARK: - Observers

    private func addObservers() {

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    @objc func applicationWillResignActive() {
        print("applicationWillResignActive")
        UserDefaults.standard.set(CACurrentMediaTime(), forKey: "applicationWillResignActiveStartTime")
    }

    @objc func applicationDidBecomeActive() {
        print("applicationDidBecomeActive")
        if let time = UserDefaults.standard.object(forKey: "applicationWillResignActiveStartTime") as? CFTimeInterval {
            slideInactiveTime = CACurrentMediaTime() - time
            print("Inactive time is \(slideInactiveTime)")
            UserDefaults.standard.removeObject(forKey: "applicationWillResignActiveStartTime")
        }
    }

    // MARK: - Setup

    private func setupWebViewConfiguration() {

        webView.configuration.processPool = WKProcessPool()
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.suppressesIncrementalRendering = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = mediaPlaybackRequiresUserAction
        webView.configuration.allowsPictureInPictureMediaPlayback = true
        webView.configuration.selectionGranularity = .character

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true

        webView.configuration.preferences = preferences
    }

    private func setupUI() {}

    private func createOrRestoreSessionIfNeed() {
        guard let bridge = bridge else { return }

        if let unfinishedSession = bridge.sessions.unfinishedSession() {
            self.showRestoreSessionAlert(bridge: bridge, unfinishedSession: unfinishedSession)
        } else {
            bridge.sessions.addNewSession()
        }
    }

    private func showRestoreSessionAlert(bridge: SCLMBridge, unfinishedSession: SCLMBridgeSession) {
        self.yesAlert(title: "Восстановление", message: "Восстановить предыдущую сессию?") {
            bridge.sessions.restoreUnfinishedSession()
            if let lastOpenedSlideId = bridge.sessions.lastOpenedSlideId() {
                if let lastOpenedSlide = SCLMSyncManager.shared.getSlide(withId: lastOpenedSlideId) {
                    self.loadSlide(lastOpenedSlide)
                    self.currentSlide = lastOpenedSlide
                }
            }
        } noAction: {
            bridge.sessions.updateStateForSession(session: unfinishedSession, state: SessionState.isTest)
            bridge.sessions.addNewSession()
        }
    }

    // MARK: - Actions

    @IBAction func tapGestureHandler() {
        dismissControls()
        webView.endEditing(true)
    }

    @IBAction func closeButtonPressed() {
        close(mode: .closeDefault) {
            self.dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {}

    // MARK: - Helpers

    func loadSlide(_ slide: Slide) {
        if let sourcesFolderUrl = currentPresentation.sourcesFolderUrl(), let slideName = slide.name {
            let contentDirUrl = sourcesFolderUrl.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let filePathURL = sourcesFolderUrl.appendingPathComponent(slideName)
            DispatchQueue.main.async {
                self.webView.loadFileURL(filePathURL, allowingReadAccessTo: contentDirUrl)
            }
        }
    }

    func slideDuration() -> CFTimeInterval {
        return CACurrentMediaTime() - slideStartTime - slideInactiveTime
    }

    @objc func dismissControls() {
        self.tapGesture.delegate = nil

        if let controlsTimer = controlsTimer, controlsTimer.isValid {
            controlsTimer.invalidate()
        }

        if isControlsHidden {
            controlsTimer = Timer(timeInterval: 5.0, target: self, selector: #selector(dismissControls), userInfo: nil, repeats: false)
        }

        isControlsHidden = !isControlsHidden
        self.tapGesture.delegate = self
    }

    func close(mode: ClosePresentationMode, completion: @escaping () -> Void) {

        if mode == .closeDefault {

            if let needConfirmation = currentPresentation.needConfirmation?.boolValue, needConfirmation == true {

                let ac = UIAlertController(title: "Закрыть", message: "Сохранить и выйти?", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Да", style: .default, handler: { _ in
                    self.willClose(state: .isComplete)
                    completion()
                }))
                ac.addAction(UIAlertAction(title: "Нет", style: .default, handler: { _ in
                    self.willClose(state: .isTest)
                    completion()
                }))
                ac.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))

                self.present(ac, animated: true, completion: nil)

            } else {

                let ac = UIAlertController(title: "Закрыть", message: "Сохранить и выйти?", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Да", style: .default, handler: { _ in
                    self.willClose(state: .isComplete)
                    completion()
                }))
                ac.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))

                self.present(ac, animated: true, completion: nil)
            }

        } else if mode == .closeSessionComplete {
            self.willClose(state: .isComplete)
            completion()

        } else if mode == .closeSessionTest {
            self.willClose(state: .isTest)
            completion()
        }
    }

    func willClose(state: SessionState) {
        print("[LOG] Send SLIDE SessionAction Close - \(bridge?.sessions.session.sessionId ?? "No session ID")")
        bridge?.sessions.logAction(.close, slide: currentSlide, duration: slideDuration(), navigationMethod: navigationMethod ?? "")
        bridge?.sessions.updateSlidesForCurrentSession(withSlide: self.currentSlide, duration: slideDuration())
        print("[LOG] Send BridgeSession Close - \(bridge?.sessions.session.sessionId ?? "No session ID")")
        bridge?.sessions.logAction(.close, presentation: currentPresentation)

        self.bridge?.sessions.closeSession(action: LogAction.close, state: state)
        self.bridge?.sessions.updateStateForCurrentSession(state: state)

        currentPresentation.setOpendState()
        SCLMSyncManager.shared.saveContext()
        delegate?.PresentationVCWillClose()

        webView.navigationDelegate = nil
        if webView.isLoading {
            webView.stopLoading()
        }
        controlsTimer?.invalidate()
    }

    // MARK: - SCLMWebViewProtocol

    func webViewDidStartLoad(webView: SCLMWebView) {
        // RESERVED
    }

    func webViewDidFinishLoad(webView: SCLMWebView) {
        // RESERVED
    }

    func webView(_ webView: SCLMWebView, didFailLoadWith error: NSError) {
        // RESERVED
    }

    func webViewShouldStartLoad(with request: NSURLRequest, navigationType: SLWebViewNavigationType) -> Bool {

        guard let requestUrl = request.url, let scheme = requestUrl.scheme else {
            return true
        }

        if scheme == "file" {

            if let slide = currentPresentation.slides?.filter({ $0.name == requestUrl.lastPathComponent }).first, let currentSlide = self.currentSlide {

                if currentSlide.slideId?.intValue != slide.slideId?.intValue {
                    if let backForwardListLast = backForwardList.last, backForwardListLast != currentSlide.name {
                        if let currentSlideName = currentSlide.name {
                            backForwardList.append(currentSlideName)
                        }
                    }

                    print("[LOG] Send SLIDE SessionAction Close - \(bridge?.sessions.session.sessionId ?? "No session ID")")
                    bridge?.sessions.logAction(.close, slide: self.currentSlide, duration: slideDuration(), navigationMethod: "in")
                    bridge?.sessions.updateSlidesForCurrentSession(withSlide: self.currentSlide, duration: slideDuration())

                    slideStartTime = CACurrentMediaTime()
                    slideInactiveTime = 0
                    navigationMethod = "in"

                    self.previousSlide = self.currentSlide
                    self.currentSlide = slide

                    bridge?.sessions.updateLastOpenedSlideId(self.currentSlide.slideId?.int32Value)
                    bridge?.sessions.incrementSlidesCountForCurrentSession()
                }
            }

            return true

        } else if scheme == SCLMBridgeConstants.Scheme.rawValue {

            let args = requestUrl.absoluteString.components(separatedBy: ":")
            let command = args[1]

            print("command: \(command)")

            if command == SCLMBridgeConstants.Queue.rawValue {
                bridge?.handleJavaScriptRequest()
            }

            return false
        }

        return true
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        print("navigationAction url - \(url)")

        if let scheme = url.scheme, scheme == "tel" {
            openUrl(url, errorMessage: "Ваше устройство не может совершать звонки")
            decisionHandler(.cancel)

        } else if let scheme = url.scheme, scheme == "mailto" {
            openUrl(url, errorMessage: "Невозможно открыть URL")
            decisionHandler(.cancel)

        } else {

            if webViewShouldStartLoad(with: navigationAction.request as NSURLRequest, navigationType: .other) {
                decisionHandler(.allow)

            } else {
                decisionHandler(.cancel)
            }
        }
    }

    private func openUrl(_ url: URL, errorMessage: String) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            showAlert(title: "Ошибка", message: errorMessage, cancelTitle: "OK")
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - SCLMBridgeBaseModuleProtocol

    func goToSlide(_ slide: Slide, with data: Any) {
        print("[LOG] Send SLIDE SessionAction Close - \(bridge?.sessions.session.sessionId ?? "No session ID")")
        bridge?.sessions.logAction(.close, slide: self.currentSlide, duration: slideDuration(), navigationMethod: navigationMethod ?? "")
        bridge?.sessions.updateSlidesForCurrentSession(withSlide: self.currentSlide, duration: slideDuration())

        slideStartTime = CACurrentMediaTime()
        slideInactiveTime = 0
        navigationMethod = "in"

        self.previousSlide = self.currentSlide
        self.currentSlide = slide

        bridge?.sessions.updateLastOpenedSlideId(self.currentSlide.slideId?.int32Value)
        bridge?.sessions.incrementSlidesCountForCurrentSession()

        self.loadSlide(slide)
        self.currentSlide = slide
    }

    func getNavigationData() -> Any {
        return navigationData
    }

    // MARK: - SCLMBridgePresentationModuleProtocol

    func openPresentation(_ presentation: Presentation, with slideName: String?, and data: Any?) {

        print("[LOG] Send SLIDE SessionAction Close - \(bridge?.sessions.session.sessionId ?? "No session ID")")
        bridge?.sessions.logAction(.close, slide: self.currentSlide, duration: slideDuration(), navigationMethod: navigationMethod ?? "")
        bridge?.sessions.updateSlidesForCurrentSession(withSlide: self.currentSlide, duration: slideDuration())

        print("[LOG] Send BridgeSession Close - \(bridge?.sessions.session.sessionId ?? "No session ID")")
        bridge?.sessions.logAction(.close, presentation: self.currentPresentation)

        if presentation.isContentExists() {

            bridge?.sessions.createNewSession(forPresentation: presentation)
            self.currentPresentation = presentation

            backForwardPresList.append(presentation)
            if let navigationData = data as? [String: String] {
                self.navigationData = navigationData
            }

            if let name = slideName, name.count > 0 {
                self.currentSlide = presentation.slides?.filter({ $0.name == name }).first

            } else {
                self.currentSlide = presentation.startUpSlide()
            }

            if let currentSlide = self.currentSlide {

                backForwardList.removeAll()
                if let slideName = currentSlide.name {
                    backForwardList.append(slideName)
                }

                self.loadSlide(currentSlide)
            }

        } else {
            showAlert(title: "Открытие презентации", message: "Вы пытаетесь открыть презентацию \(presentation.name ?? ""), контент которой не загружен. Загрузите контент и попробуйте еще раз.", cancelTitle: "Ok")
        }
    }

    func getPreviousSlide() -> Slide? {
        return previousSlide
    }

    func getNextSlide() -> Slide? {
        return nextSlide
    }

    func getCurrentSlideName() -> String? {
        return currentSlide.name
    }

    func getBackForwardList() -> [SlideName]? {
        return backForwardList
    }

    func getBackForwardPresList() -> [Presentation]? {
        return backForwardPresList
    }

    func closePresentation(mode: ClosePresentationMode) {
        DispatchQueue.main.async {
            self.close(mode: mode) {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    // MARK: - SCLMBridgeUIModuleProtocol

    func hideCloseBtn() {
//        closeButton.hide()
    }

    func hideSystemBtns() {
//        closeButton.hide()
    }

    // MARK: - SCLMBridgeSessionsModuleProtocol

    func setSessionComplete() {
        print("[LOG] Send BridgeSession Complete - \(bridge?.sessions.session.sessionId ?? "No session ID")")
        bridge?.sessions.logAction(.complete, presentation: self.currentPresentation)
    }

    // MARK: - SCLMBridgeCustomEventsModuleProtocol

    func setEventKey(_ key: String, and value: Any) {
        bridge?.sessions.logEventKey(key, value: value, presentation: currentPresentation)
    }

    // MARK: - SCLMBridgeMediaFilesModuleProtocol

    func openMediaFile(_ fileName: String) {}

    func openMediaLibrary() {}

    func showMediaLibraryBtn() {}

    func hideMediaLibraryBtn() {}

    // MARK: - SCLMBridgeMapModuleProtocol

    func hideMapBtn() {}

    func showMapBtn() {}

    // MARK: - MapViewControllerProtocol

    func decodeAndLoadSlide(_ slide: Slide) {

        print("[LOG] Send SLIDE SessionAction Close - \(bridge?.sessions.session.sessionId ?? "No session ID")")
        bridge?.sessions.logAction(.close, slide: currentSlide, duration: slideDuration(), navigationMethod: navigationMethod ?? "")
        bridge?.sessions.updateSlidesForCurrentSession(withSlide: self.currentSlide, duration: slideDuration())

        slideStartTime = CACurrentMediaTime()
        slideInactiveTime = 0
        navigationMethod = "out"
        previousSlide = currentSlide
        currentSlide = slide

        bridge?.sessions.updateLastOpenedSlideId(self.currentSlide.slideId?.int32Value)
        bridge?.sessions.incrementSlidesCountForCurrentSession()

        loadSlide(slide)
    }

    // MARK: -

    fileprivate func showAlert(title: String?, message: String?, cancelTitle: String?, cancelAction: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: cancelTitle, style: UIAlertAction.Style.cancel, handler: { _ in
            cancelAction?()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    fileprivate func yesAlert(title: String?, message: String?, yesAction: @escaping () -> Void, noAction: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "Нет", style: UIAlertAction.Style.destructive, handler: { _ in
            noAction?()
        }))
        alert.addAction(UIAlertAction(title: "Да", style: UIAlertAction.Style.default, handler: { _ in
            yesAction()
        }))
        self.present(alert, animated: true, completion: nil)
    }
}

extension PresentationVC {
    func inject(presentation: Presentation) {
        self.currentPresentation = presentation
        self.scriptStorage = CustomScriptStorage(with: presentation)
    }
}

// MARK: - SCLMLocationManagerDelegate

extension PresentationVC: SCLMLocationManagerDelegate {
    func authorizationStatusNoAccess(manager: SCLMLocationManager) {
        showAlert(title: "Нет доступа к геопозиции", message: "Перейдите в настройки, чтобы предоставить доступ.", cancelTitle: "OK", cancelAction: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
    }

    func locationServicesDisabled(manager: SCLMLocationManager) {
        showAlert(title: "Службы геолокации отключены", message: "Перейдите в Настройки -> Конфиденциальность, чтобы включить службы геолокации.", cancelTitle: "Ok")
    }

    func authorizationStatusAccessGranted(manager: SCLMLocationManager) {
        print("authorizationStatusAccessGranted")
    }
}

// MARK: - CLLocationManagerDelegate

extension PresentationVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // RESERVED
    }
}

extension UIView {
    func show() {
        DispatchQueue.main.async {
            self.isHidden = false
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.isHidden = true
        }
    }
}

extension PresentationVC: WKScriptMessageHandler {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.getAppState()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        switch message.name {
        case PresentationVC.MessageHandler.logHandler.rawValue:
            (self.tabBarController as? TabBarController)?.addLog(String(describing: message.body))
            print("LOG: \(message.body)")
        case PresentationVC.MessageHandler.setStoryProp.rawValue:
            guard let data = (message.body as? String)?.data(using: String.Encoding.utf8) else {
                print("[PresentationVC: WKScriptMessageHandler ] can't parse setStoryProp data")
                return
            }
            guard let propModel = try? JSONDecoder().decode(SetPropModel.self, from: data) else {
                print("[PresentationVC: WKScriptMessageHandler ] can't decode setStoryProp model")
                return
            }
            self.setStoryProp(propModel)
        case PresentationVC.MessageHandler.deleteStoryProp.rawValue:
            guard let data = (message.body as? String)?.data(using: String.Encoding.utf8) else {
                print("[PresentationVC: WKScriptMessageHandler ] can't parse deleteStoryProp data")
                return
            }
            guard let propModel = try? JSONDecoder().decode(DeletePropModel.self, from: data) else {
                print("[PresentationVC: WKScriptMessageHandler ] can't decode deleteStoryProp model")
                return
            }
            self.deleteStoryProp(propModel)
        default:
            break
        }
    }
}

extension PresentationVC {

    func setStoryProp(_ prop: SetPropModel) {
        let newConfig = self.scriptStorage.setPropModel(prop)
        self.addConfiguration(newConfig.asJson())
    }

    func deleteStoryProp(_ prop: DeletePropModel) {
        let newConfig = self.scriptStorage.deleteStoryProp(prop)
        self.addConfiguration(newConfig.asJson())
    }

    func addConfiguration(_ text: String) {
        let js = """
        window._story = \(text)
        _onStoryChange();
        """

        self.webView.evaluateJavaScript(js, completionHandler: { frame, error in
            if let error = error {
                print("Error: \(error)")
            } else {
                self.getAppState()
            }
        })
    }

    func getAppState() {
        self.webView.evaluateJavaScript("window._story", completionHandler: { frame, error in
            let storyModel = frame as? [String: Any]
            self.scriptStorage.setStoryModel(storyModel)
        })
    }
}
