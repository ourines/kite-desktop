# KiteApp – Swift Native iOS / iPadOS / macOS App

A native SwiftUI application for managing Kubernetes clusters, mirroring the feature set of the **Kite Desktop** web UI.

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS / iPadOS | 17.0 |
| macOS (Catalyst) | 14.0 (Sonoma) |

Xcode 15 or later is required to build.

## Architecture

The app **does not embed** the Go backend. Users run `kite-desktop` (or expose its API) on their Mac or server, then configure the base URL inside the app.

All REST and WebSocket endpoints match the Go server verbatim:

```
Base URL  : http(s)://<host>:<port>
REST      : /api/v1/...
WebSocket : /api/v1/logs/:ns/:pod/ws
            /api/v1/terminal/:ns/:pod/ws
            /api/v1/kubectl-terminal/ws
            /api/v1/node-terminal/:nodeName/ws
```

## Directory Layout

```
KiteApp/
├── Package.swift
├── Sources/KiteApp/
│   ├── App/                 # @main entry, RootView, AppDelegate
│   ├── Models/
│   │   ├── K8s/             # Codable wrappers for every K8s resource
│   │   └── AI/              # AI session / message models
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   ├── WebSocketClient.swift
│   │   └── Endpoints/       # Typed endpoint definitions
│   ├── Features/
│   │   ├── Cluster/         # Cluster list, form, add/edit/delete
│   │   ├── Overview/        # Dashboard with charts and stats
│   │   ├── Resources/       # Generic resource list + detail + YAML editor
│   │   ├── Pod/             # Logs, Terminal, File browser
│   │   ├── AI/              # Chat UI, session management
│   │   ├── Search/          # Global search with history
│   │   ├── Templates/       # YAML template CRUD
│   │   └── Settings/        # General, AI, About tabs
│   ├── Components/
│   │   ├── Charts/          # Swift Charts wrappers
│   │   ├── ResourceStatusBadge.swift
│   │   ├── MetricCard.swift
│   │   ├── SidebarView.swift
│   │   ├── TerminalView.swift   # WKWebView + xterm.js
│   │   └── YAMLEditorView.swift # WKWebView + CodeMirror 6
│   ├── Persistence/         # SwiftData models + stores
│   ├── Extensions/          # View+, Color+, Date+
│   └── Resources/           # Assets, xterm.js, codemirror bundle
└── Tests/KiteAppTests/
```

## Building

Open `Package.swift` in Xcode (File → Open…) and select the **KiteApp** scheme, or run:

```bash
cd KiteApp
xcodebuild -scheme KiteApp -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)'
```

## Platform Adaptations

| Feature | iPhone | iPad | Mac Catalyst |
|---------|--------|------|--------------|
| Navigation | `NavigationStack` | `NavigationSplitView` (3-col) | `NavigationSplitView` + menu bar |
| Sidebar | Bottom `TabView` + sheet | Persistent sidebar | Persistent sidebar |
| Terminal / Logs | Full-screen sheet | Detail column | Detail column |
| YAML Editor | Full-screen sheet | Side panel | Side panel |
| Keyboard shortcuts | — | External keyboard | Full ⌘ set |
| File drop | — | Drop kubeconfig | Drop kubeconfig |

## Backend Setup

1. Download and run `kite-desktop` from the [releases page](https://github.com/ourines/kite-desktop/releases).
2. Note the port it binds to (default `9090`).
3. In the app, go to **Settings → Clusters → Add Cluster** and enter `http://localhost:9090`.
