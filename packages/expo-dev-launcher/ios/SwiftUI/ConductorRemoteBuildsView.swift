// Copyright 2015-present 650 Industries. All rights reserved.

import SwiftUI
import WebKit

struct ConductorRemoteBuildsView: View {
  let url: URL
  let onClose: () -> Void
  let onConnected: () -> Void
  let onOpenApp: (String) -> Void

  var body: some View {
    NavigationView {
      ConductorRemoteBuildsWebView(
        url: url,
        onConnected: onConnected,
        onOpenApp: onOpenApp
      )
      .navigationTitle("Remote builds")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") {
            onClose()
          }
        }
      }
    }
  }
}

private struct ConductorRemoteBuildsWebView: UIViewRepresentable {
  let url: URL
  let onConnected: () -> Void
  let onOpenApp: (String) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(url: url, onConnected: onConnected, onOpenApp: onOpenApp)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    context.coordinator.loadInitialURL(in: webView)
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {}

  final class Coordinator: NSObject, WKNavigationDelegate {
    private let url: URL
    private let onConnected: () -> Void
    private let onOpenApp: (String) -> Void
    private var didCompleteConnection = false

    init(url: URL, onConnected: @escaping () -> Void, onOpenApp: @escaping (String) -> Void) {
      self.url = url
      self.onConnected = onConnected
      self.onOpenApp = onOpenApp
    }

    func loadInitialURL(in webView: WKWebView) {
      copySharedCookies(to: webView, for: url) {
        webView.load(URLRequest(url: self.url))
      }
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url else {
        decisionHandler(.allow)
        return
      }

      if let appURL = appURL(from: url) {
        copyCookies(from: webView) { [onOpenApp] in
          onOpenApp(appURL)
        }
        decisionHandler(.cancel)
        return
      }

      decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      copyCookies(from: webView) { [weak self, weak webView] in
        guard let self,
              let webView,
              self.isConnectedPage(webView.url),
              !self.didCompleteConnection else {
          return
        }

        self.didCompleteConnection = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [onConnected] in
          onConnected()
        }
      }
    }

    private func appURL(from url: URL) -> String? {
      guard url.host == "expo-development-client",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems else {
        return nil
      }

      return queryItems.first { $0.name == "url" }?.value
    }

    private func isConnectedPage(_ url: URL?) -> Bool {
      guard let url else {
        return false
      }

      return url.path == "/connected"
    }

    private func copyCookies(from webView: WKWebView, completion: (() -> Void)? = nil) {
      webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
        for cookie in cookies {
          HTTPCookieStorage.shared.setCookie(cookie)
        }
        DispatchQueue.main.async {
          completion?()
        }
      }
    }

    private func copySharedCookies(to webView: WKWebView, for url: URL, completion: @escaping () -> Void) {
      guard let cookies = HTTPCookieStorage.shared.cookies(for: url),
            !cookies.isEmpty else {
        completion()
        return
      }

      let group = DispatchGroup()
      let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
      for cookie in cookies {
        group.enter()
        cookieStore.setCookie(cookie) {
          group.leave()
        }
      }

      group.notify(queue: .main) {
        completion()
      }
    }
  }
}
