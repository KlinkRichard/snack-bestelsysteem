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

        // Use default (persistent) data store for cookies & localStorage
        config.websiteDataStore = .default()

        // JavaScript preferences
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
        webView.backgroundColor = UIColor(red: 15/255, green: 17/255, blue: 32/255, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 15/255, green: 17/255, blue: 32/255, alpha: 1)

        // Disable pinch zoom
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0

        // Custom User-Agent so the website knows it's the native app
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) AZERTYSnacks-iOS/1.0"

        // Pull to refresh
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        context.coordinator.webView = webView

        // Load the app
        if let url = URL(string: baseURL + "/index.html") {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadRevalidatingCacheData
            webView.load(request)
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?

        @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                refreshControl.endRefreshing()
            }
        }

        // MARK: - Navigation Delegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let host = url.host?.lowercased() ?? ""

            // Allow all Vercel domains (including preview deployments)
            if host.hasSuffix("vercel.app") || host.hasSuffix("vercel.com") {
                decisionHandler(.allow)
                return
            }

            // Allow Microsoft SSO
            if host.hasSuffix("microsoftonline.com") ||
               host.hasSuffix("microsoft.com") ||
               host.hasSuffix("live.com") ||
               host.hasSuffix("msauth.net") ||
               host.hasSuffix("msftauth.net") {
                decisionHandler(.allow)
                return
            }

            // Allow Anthropic API
            if host.hasSuffix("anthropic.com") {
                decisionHandler(.allow)
                return
            }

            // External links: open in Safari
            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // Allow everything else (API calls etc.)
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject CSS tweaks for native app feel
            let js = """
            (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                    body { -webkit-touch-callout: none; }
                    /* Hide "add to homescreen" banners if any */
                    .pwa-install-prompt { display: none !important; }
                `;
                document.head.appendChild(style);

                // Signal to the web app that we're in a native wrapper
                window.isNativeApp = true;
            })();
            """
            webView.evaluateJavaScript(js)
        }

        // MARK: - UI Delegate

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

        // Open target="_blank" links in same webview
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
