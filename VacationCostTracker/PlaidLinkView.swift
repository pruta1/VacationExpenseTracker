import SwiftUI
import WebKit

// MARK: - Plaid Link View
//
// Uses Plaid's hosted Link UI in a WKWebView.
// This avoids needing to add the Plaid iOS SDK as an SPM dependency.
//
// How it works:
//   1. Backend generates a link_token  (POST /plaid/create-link-token)
//   2. We load the Plaid Link hosted URL with that token
//   3. The user authenticates with their bank inside the WebView
//   4. On success, Plaid redirects to a custom URL scheme we intercept
//   5. We extract the public_token from the URL and call the onSuccess handler
//
// IMPORTANT: You must register the URL scheme "vacationtracker" in Xcode:
//   Target > Info > URL Types > Add item
//   Identifier: com.yourname.VacationCostTracker
//   URL Schemes: vacationtracker
//
// In your Plaid dashboard (https://dashboard.plaid.com/team/api), add this
// as an allowed redirect URI:  vacationtracker://plaid/callback

struct PlaidLinkView: UIViewControllerRepresentable {
    let linkToken: String
    let onSuccess: (_ publicToken: String, _ institutionName: String) -> Void
    let onExit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess, onExit: onExit)
    }

    func makeUIViewController(context: Context) -> PlaidLinkViewController {
        PlaidLinkViewController(
            linkToken: linkToken,
            coordinator: context.coordinator
        )
    }

    func updateUIViewController(_ vc: PlaidLinkViewController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator {
        let onSuccess: (String, String) -> Void
        let onExit: () -> Void
        init(onSuccess: @escaping (String, String) -> Void, onExit: @escaping () -> Void) {
            self.onSuccess = onSuccess
            self.onExit = onExit
        }
    }
}

// MARK: - PlaidLinkViewController

final class PlaidLinkViewController: UIViewController {
    private let linkToken: String
    private let coordinator: PlaidLinkView.Coordinator
    private var webView: WKWebView!

    init(linkToken: String, coordinator: PlaidLinkView.Coordinator) {
        self.linkToken = linkToken
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Cancel button in top-left
        let cancelBtn = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(didTapCancel)
        )
        navigationItem.leftBarButtonItem = cancelBtn

        // Configure WKWebView — message handler lets HTML call back into Swift
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(PlaidScriptHandler(coordinator: coordinator, vc: self), name: "plaidHandler")
        config.userContentController = contentController

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        view.addSubview(webView)

        // Loading overlay shown while Plaid's page initialises
        let overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .systemBackground
        overlay.tag = 8888

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()

        let label = UILabel()
        label.text = "Loading bank connection…"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel

        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(label)
        overlay.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        view.addSubview(overlay)

        loadPlaidLink()
    }

    private func hideLoadingOverlay() {
        view.viewWithTag(8888)?.removeFromSuperview()
    }

    private func loadPlaidLink() {
        // Escape the token for safe inline JS embedding
        let safeToken = linkToken
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        // Local HTML page that bootstraps Plaid's official web SDK.
        // Setting baseURL to cdn.plaid.com lets the external script load without
        // same-origin restrictions and matches what Plaid's SDK expects.
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <style>
            * { margin:0; padding:0; box-sizing:border-box; }
            html, body { width:100%; height:100vh; overflow:hidden; background:#fff; }
          </style>
        </head>
        <body>
        <script src="https://cdn.plaid.com/link/v2/stable/link-initialize.js"></script>
        <script>
        (function() {
          var handler = Plaid.create({
            token: '\(safeToken)',
            onSuccess: function(public_token, metadata) {
              var instName = (metadata && metadata.institution && metadata.institution.name)
                ? metadata.institution.name : 'Bank';
              // Navigate to custom URL scheme — intercepted by handleCallbackURL in Swift.
              // More reliable than postMessage because it works from any JS context.
              window.location.href = 'vacationtracker://plaid/callback?public_token='
                + encodeURIComponent(public_token)
                + '&institution_name=' + encodeURIComponent(instName);
            },
            onExit: function(err, metadata) {
              window.location.href = 'vacationtracker://plaid/callback?exit=1';
            },
            onLoad: function() { handler.open(); },
            onEvent: function(eventName, metadata) {}
          });
        })();
        </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://cdn.plaid.com"))
    }

    @objc private func didTapCancel() {
        coordinator.onExit()
        dismiss(animated: true)
    }

    // Intercepts custom URL scheme: vacationtracker://plaid/callback?...
    private func handleCallbackURL(_ url: URL) -> Bool {
        guard url.scheme == "vacationtracker",
              url.host == "plaid",
              url.path == "/callback" else { return false }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
        )

        if let publicToken = params["public_token"] {
            let institutionName = params["institution_name"] ?? "Bank"
            coordinator.onSuccess(publicToken, institutionName)
            dismiss(animated: true)
            return true
        }
        if params["exit"] != nil {
            coordinator.onExit()
            dismiss(animated: true)
            return true
        }
        return false
    }

}

// MARK: - WKNavigationDelegate

extension PlaidLinkViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        // Intercept our success/exit callback
        if handleCallbackURL(url) {
            decisionHandler(.cancel)
            return
        }
        // Let http/https through normally
        if url.scheme == "http" || url.scheme == "https" {
            decisionHandler(.allow)
            return
        }
        // Any other scheme (plaidlink://, bank app deep links, etc.) — open via iOS
        decisionHandler(.cancel)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoadingOverlay()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        hideLoadingOverlay()
        showWebError(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let code = (error as NSError).code
        // NSURLErrorUnsupportedURL (-1002): non-http deep link already handled in decidePolicyFor — ignore
        guard code != NSURLErrorUnsupportedURL else { return }
        hideLoadingOverlay()
        showWebError(error.localizedDescription)
    }

    private func showWebError(_ message: String) {
        let alert = UIAlertController(
            title: "Couldn't load Plaid",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.loadPlaidLink()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.coordinator.onExit()
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - WKUIDelegate

extension PlaidLinkViewController: WKUIDelegate {
    // Plaid opens the bank's OAuth/login page via window.open().
    // We must return a real WKWebView so window.opener is preserved —
    // Plaid uses window.opener.postMessage to fire onSuccess after OAuth completes.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let popup = WKWebView(frame: view.bounds, configuration: configuration)
        popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popup.navigationDelegate = self
        popup.uiDelegate = self
        view.addSubview(popup)
        return popup
    }

    // Called when Plaid's JS calls window.close() on the popup after OAuth completes.
    func webViewDidClose(_ webView: WKWebView) {
        if webView !== self.webView {
            webView.removeFromSuperview()
        }
    }
}

// MARK: - Script Message Handler

private final class PlaidScriptHandler: NSObject, WKScriptMessageHandler {
    weak var coordinator: PlaidLinkView.Coordinator?
    weak var vc: PlaidLinkViewController?

    init(coordinator: PlaidLinkView.Coordinator, vc: PlaidLinkViewController) {
        self.coordinator = coordinator
        self.vc = vc
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? String,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let action = json["action"] as? String ?? json["type"] as? String ?? ""

        switch action {
        case "plaidLinkSuccess", "HANDOFF":
            if let metadata    = json["metadata"] as? [String: Any],
               let publicToken = metadata["public_token"] as? String {
                let institution = (metadata["institution"] as? [String: Any])?["name"] as? String ?? "Bank"
                coordinator?.onSuccess(publicToken, institution)
                vc?.dismiss(animated: true)
            }
        case "plaidLinkExit", "EXIT":
            coordinator?.onExit()
            vc?.dismiss(animated: true)
        default:
            break
        }
    }
}

// MARK: - Loading Wrapper View
//
// Handles async link-token fetch + shows the WebView once ready.

struct PlaidLinkContainer: View {
    let plaidService: PlaidService
    let onSuccess: (_ publicToken: String, _ institutionName: String) -> Void
    let onExit: () -> Void

    @State private var linkToken: String?
    @State private var isLoading = true
    @State private var statusText = "Connecting to Plaid…"
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.accentColor)
                    Text(statusText)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Button("Cancel", action: onExit)
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 4)
                }
                .padding(32)
                .background(Color(.systemBackground))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else if let token = linkToken {
                NavigationStack {
                    PlaidLinkView(linkToken: token, onSuccess: onSuccess, onExit: onExit)
                        .ignoresSafeArea()
                        .navigationTitle("Connect Bank")
                        .navigationBarTitleDisplayMode(.inline)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Could not connect to server")
                        .font(.headline)
                    if let err = error {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Text("Backend: \(PlaidService.backendURL)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Button("Try Again") { fetchToken() }
                        .buttonStyle(.borderedProminent)
                    Button("Cancel", action: onExit)
                }
                .padding()
            }
        }
        .onAppear { fetchToken() }
    }

    private func fetchToken() {
        isLoading = true
        error = nil
        statusText = "Connecting to server…"
        Task { @MainActor in
            do {
                statusText = "Requesting link token…"
                linkToken = try await plaidService.createLinkToken()
                statusText = "Opening bank connection…"
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
