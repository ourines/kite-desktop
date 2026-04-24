import SwiftUI
import WebKit

// MARK: – TerminalView
// Embeds xterm.js in a WKWebView and bridges a WebSocket connection.

struct TerminalView: UIViewRepresentable {
    let webSocketURL: URL?
    @Binding var input: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "terminalOutput")
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .black
        wv.scrollView.isScrollEnabled = false
        context.coordinator.webView = wv
        if let url = webSocketURL {
            context.coordinator.connect(wsURL: url, webView: wv)
        }
        wv.loadHTMLString(terminalHTML, baseURL: nil)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if !input.isEmpty {
            let escaped = input
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            uiView.evaluateJavaScript("sendInput('\(escaped)')", completionHandler: nil)
            DispatchQueue.main.async { input = "" }
        }
    }

    // MARK: – Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, URLSessionWebSocketDelegate {
        weak var webView: WKWebView?
        private var wsTask: URLSessionWebSocketTask?
        private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

        func connect(wsURL: URL, webView: WKWebView) {
            self.webView = webView
            wsTask = session.webSocketTask(with: wsURL)
            wsTask?.resume()
            receive()
        }
        private func receive() {
            wsTask?.receive { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let msg):
                    var text: String
                    switch msg {
                    case .string(let s): text = s
                    case .data(let d):   text = String(data: d, encoding: .utf8) ?? ""
                    @unknown default:    text = ""
                    }
                    let escaped = text
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "`", with: "\\`")
                    DispatchQueue.main.async {
                        self.webView?.evaluateJavaScript("writeToTerminal(`\(escaped)`)", completionHandler: nil)
                    }
                    self.receive()
                case .failure: break
                }
            }
        }

        func sendInput(_ text: String) {
            wsTask?.send(.string(text)) { _ in }
        }

        // WKScriptMessageHandler – receive "terminalOutput" messages from xterm
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "terminalOutput", let text = message.body as? String else { return }
            wsTask?.send(.string(text)) { _ in }
        }
    }
}

// MARK: – xterm.js HTML template
//
// NOTE: For production builds, replace the CDN URLs below with locally bundled
// copies placed in Sources/KiteApp/Resources/xterm/.
// e.g. add xterm.js, xterm.css, and xterm-addon-fit.js to the Resources folder
// and reference them via bundle URLs using WKWebView.loadFileURL(_:allowingReadAccessTo:).

private let terminalHTML = """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css"/>
<script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.js"></script>
<script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.js"></script>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
body { background:#1a1b26; width:100vw; height:100vh; overflow:hidden; }
#terminal { width:100%; height:100%; }
</style>
</head>
<body>
<div id="terminal"></div>
<script>
const term = new Terminal({ theme: { background:'#1a1b26', foreground:'#a9b1d6' }, fontFamily:'monospace', fontSize:14, cursorBlink:true });
const fitAddon = new FitAddon.FitAddon();
term.loadAddon(fitAddon);
term.open(document.getElementById('terminal'));
fitAddon.fit();
window.addEventListener('resize', () => fitAddon.fit());
term.onData(data => { window.webkit.messageHandlers.terminalOutput.postMessage(data); });
function writeToTerminal(text) { term.write(text); }
function sendInput(text) { if(window.webkit) window.webkit.messageHandlers.terminalOutput.postMessage(text); }
</script>
</body>
</html>
"""
