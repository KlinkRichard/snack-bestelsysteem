import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    private let baseURL = "https://snack-bestelsysteem.vercel.app"

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Allow localStorage and cookies
        config.websiteDataStore = .default()

        // Preferences
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.bounces = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 15/255, green: 17/255, blue: 32/255, alpha: 1) // #0f1120

        // Match the dark background while loading
        webView.scrollView.backgroundColor = UIColor(red: 15/255, green: 17/255, blue: 32/255, alpha: 1)

        // Disable zoom (we handle it in CSS)
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0

        // Pull to refresh
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        context.coordinator.webView = webView

        // Load the app
        if let url = URL(string: baseURL + "/index.html") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?

        @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                refreshControl.endRefreshing()
            }
        }

        // MARK: - Navigation Delegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let urlString = url.absoluteString

            // Allow navigation within our app
            if urlString.contains("snack-bestelsysteem.vercel.app") {
                decisionHandler(.allow)
                return
            }

            // Allow Microsoft SSO login flow
            if urlString.contains("login.microsoftonline.com") ||
               urlString.contains("login.live.com") ||
               urlString.contains("microsoft.com") {
                decisionHandler(.allow)
                return
            }

            // Allow Anthropic API calls (for chat)
            if urlString.contains("api.anthropic.com") {
                decisionHandler(.allow)
                return
            }

            // External links: open in Safari
            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject CSS to handle the status bar area
            let css = """
            body {
                -webkit-touch-callout: none;
            }
            """
            let js = """
            var style = document.createElement('style');
            style.innerHTML = `\(css)`;
            document.head.appendChild(style);
            """
            webView.evaluateJavaScript(js)
        }

        // MARK: - UI Delegate (handle alerts, confirms, prompts)

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })
            topViewController()?.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Annuleer", style: .cancel) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })
            topViewController()?.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.text = defaultText
            }
            alert.addAction(UIAlertAction(title: "Annuleer", style: .cancel) { _ in
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            topViewController()?.present(alert, animated: true)
        }

        // Open new windows (target="_blank") in the same webview
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil || !(navigationAction.targetFrame!.isMainFrame) {
                webView.load(navigationAction.request)
            }
            return nil
        }

        private func topViewController() -> UIViewController? {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }),
                  var top = window.rootViewController else { return nil }
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }
    }
}
