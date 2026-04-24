import SwiftUI
import WebKit

// MARK: – YAMLEditorView
// Embeds CodeMirror 6 in a WKWebView for syntax-highlighted YAML editing.

struct YAMLEditorView: UIViewRepresentable {
    @Binding var text: String
    var isReadOnly: Bool = false

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(context.coordinator, name: "contentChanged")
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        context.coordinator.webView = wv
        wv.loadHTMLString(editorHTML(initial: text, readOnly: isReadOnly), baseURL: nil)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.lastValue != text else { return }
        context.coordinator.lastValue = text
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        uiView.evaluateJavaScript("setContent(`\(escaped)`)", completionHandler: nil)
    }

    // MARK: – Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var text: String
        var lastValue: String = ""
        weak var webView: WKWebView?

        init(text: Binding<String>) { _text = text }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "contentChanged", let val = message.body as? String else { return }
            lastValue = val
            DispatchQueue.main.async { self.text = val }
        }
    }
}

// MARK: – CodeMirror 6 HTML
//
// NOTE: For production builds, replace the CDN ESM imports below with locally
// bundled copies.  Build a CodeMirror bundle (e.g. via esbuild/Rollup) and
// place it in Sources/KiteApp/Resources/codemirror/cm6.bundle.js, then load
// it with WKWebView.loadFileURL(_:allowingReadAccessTo:).

private func editorHTML(initial: String, readOnly: Bool) -> String {
    let escaped = initial
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "`", with: "\\`")
    let readOnlyJS = readOnly ? "true" : "false"
    return """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<script type="module">
import { EditorView, basicSetup } from "https://cdn.jsdelivr.net/npm/codemirror@6.0.1/+esm";
import { yaml } from "https://cdn.jsdelivr.net/npm/@codemirror/lang-yaml@6.0.0/+esm";
import { oneDark } from "https://cdn.jsdelivr.net/npm/@codemirror/theme-one-dark@6.1.2/+esm";
import { EditorState } from "https://cdn.jsdelivr.net/npm/@codemirror/state@6.4.1/+esm";

const initialContent = `\(escaped)`;
const readOnly = \(readOnlyJS);

let state = EditorState.create({
  doc: initialContent,
  extensions: [
    basicSetup,
    yaml(),
    oneDark,
    EditorView.editable.of(!readOnly),
    EditorView.updateListener.of(update => {
      if (update.docChanged) {
        window.webkit.messageHandlers.contentChanged.postMessage(update.state.doc.toString());
      }
    })
  ]
});

const view = new EditorView({ state, parent: document.getElementById("editor") });

window.setContent = (text) => {
  view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: text } });
};
window.getContent = () => view.state.doc.toString();
</script>
<style>
* { margin:0; padding:0; box-sizing:border-box; }
html, body { height:100%; width:100%; overflow:hidden; }
#editor { height:100%; font-size:13px; }
.cm-editor { height:100%; }
.cm-scroller { overflow:auto; }
</style>
</head>
<body>
<div id="editor"></div>
</body>
</html>
"""
}
