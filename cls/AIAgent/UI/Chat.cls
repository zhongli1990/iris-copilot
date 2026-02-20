/// CSP page: Chat UI for the IRIS AI Agent Platform.
/// Renders a complete single-page chat interface with conversation management,
/// SSE streaming, code review panel, and production/runner status.
/// 
/// Uses Alpine.js for reactivity, Marked.js for Markdown rendering, and
/// native EventSource for SSE streaming from the AI Agent Bridge.
/// 
/// Part of the IRIS AI Agent Platform (OpenLI IRIS CoPilot).
Class AIAgent.UI.Chat Extends %CSP.Page
{

/// Content type for this page.
Parameter CONTENTTYPE = "text/html";

/// Page title shown in browser tab.
Parameter PAGETITLE = "OpenLI IRIS CoPilot";

/// Require authenticated session.
Parameter SECURITYRESOURCE = "%Development";

/// Render the full chat interface as a single self-contained HTML page.
ClassMethod OnPage() As %Status
{
    &html<<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenLI IRIS CoPilot</title>

    <!-- Alpine.js for reactivity -->
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
    <!-- Marked.js for Markdown rendering -->
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>

    <style>
        /* ===== CSS Reset & Base ===== */
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        :root {
            --nhs-blue: #005EB8;
            --nhs-blue-dark: #003d7a;
            --nhs-blue-light: #4189d4;
            --bg-primary: #0d1117;
            --bg-secondary: #161b22;
            --bg-tertiary: #1c2129;
            --bg-elevated: #21262d;
            --bg-hover: #292e36;
            --border-color: #30363d;
            --border-light: #3d444d;
            --text-primary: #e6edf3;
            --text-secondary: #8b949e;
            --text-muted: #6e7681;
            --user-bubble: #1a3a5c;
            --ai-bubble: #1c2129;
            --success: #2ea043;
            --warning: #d29922;
            --error: #f85149;
            --code-bg: #0d1117;
            --sidebar-width: 280px;
            --right-panel-width: 380px;
            --input-area-height: auto;
            --transition-fast: 150ms ease;
            --transition-normal: 250ms ease;
        }

        html, body {
            height: 100%;
            overflow: hidden;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            font-size: 14px;
            line-height: 1.5;
            color: var(--text-primary);
            background: var(--bg-primary);
        }

        /* ===== Scrollbar ===== */
        ::-webkit-scrollbar { width: 6px; height: 6px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: var(--border-color); border-radius: 3px; }
        ::-webkit-scrollbar-thumb:hover { background: var(--border-light); }

        /* ===== App Layout ===== */
        .app-container {
            display: flex;
            height: 100vh;
            width: 100%;
        }

        /* ===== Left Sidebar: Conversations ===== */
        .sidebar {
            width: var(--sidebar-width);
            min-width: var(--sidebar-width);
            background: var(--bg-secondary);
            border-right: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            transition: margin-left var(--transition-normal), opacity var(--transition-normal);
            z-index: 20;
        }

        .sidebar.collapsed {
            margin-left: calc(-1 * var(--sidebar-width));
            opacity: 0;
            pointer-events: none;
        }

        .sidebar-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 14px 16px;
            border-bottom: 1px solid var(--border-color);
        }

        .sidebar-header h2 {
            font-size: 14px;
            font-weight: 600;
            color: var(--text-primary);
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .sidebar-header h2 .logo-icon {
            width: 20px;
            height: 20px;
            background: var(--nhs-blue);
            border-radius: 4px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 11px;
            font-weight: 700;
            color: #fff;
        }

        .btn-new-chat {
            background: var(--nhs-blue);
            color: #fff;
            border: none;
            padding: 6px 12px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 500;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 4px;
            transition: background var(--transition-fast);
        }

        .btn-new-chat:hover { background: var(--nhs-blue-dark); }

        .conversation-list {
            flex: 1;
            overflow-y: auto;
            padding: 8px;
        }

        .conversation-item {
            padding: 10px 12px;
            border-radius: 8px;
            cursor: pointer;
            transition: background var(--transition-fast);
            margin-bottom: 2px;
        }

        .conversation-item:hover { background: var(--bg-hover); }

        .conversation-item.active {
            background: var(--nhs-blue);
            color: #fff;
        }

        .conversation-item .conv-title {
            font-size: 13px;
            font-weight: 500;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .conversation-item .conv-meta {
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 2px;
        }

        .conversation-item.active .conv-meta { color: rgba(255,255,255,0.7); }

        .sidebar-footer {
            padding: 12px 16px;
            border-top: 1px solid var(--border-color);
            font-size: 11px;
            color: var(--text-muted);
            text-align: center;
        }

        /* ===== Main Chat Area ===== */
        .main-area {
            flex: 1;
            display: flex;
            flex-direction: column;
            min-width: 0;
            position: relative;
        }

        /* Top Bar */
        .top-bar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 10px 16px;
            border-bottom: 1px solid var(--border-color);
            background: var(--bg-secondary);
            min-height: 48px;
        }

        .top-bar-left {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .top-bar-right {
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .btn-icon {
            background: transparent;
            color: var(--text-secondary);
            border: 1px solid var(--border-color);
            width: 34px;
            height: 34px;
            border-radius: 6px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            transition: all var(--transition-fast);
        }

        .btn-icon:hover {
            background: var(--bg-hover);
            color: var(--text-primary);
            border-color: var(--border-light);
        }

        .conversation-title-display {
            font-size: 14px;
            font-weight: 600;
            color: var(--text-primary);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            max-width: 400px;
        }

        .health-badge {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            font-size: 11px;
            padding: 3px 10px;
            border-radius: 12px;
            font-weight: 500;
        }

        .health-badge.online {
            background: rgba(46, 160, 67, 0.15);
            color: var(--success);
            border: 1px solid rgba(46, 160, 67, 0.3);
        }

        .health-badge.offline {
            background: rgba(248, 81, 73, 0.15);
            color: var(--error);
            border: 1px solid rgba(248, 81, 73, 0.3);
        }

        .health-dot {
            width: 7px;
            height: 7px;
            border-radius: 50%;
            display: inline-block;
        }

        .health-badge.online .health-dot { background: var(--success); }
        .health-badge.offline .health-dot { background: var(--error); }

        /* Messages Container */
        .messages-container {
            flex: 1;
            overflow-y: auto;
            padding: 24px 0;
        }

        .messages-inner {
            max-width: 800px;
            margin: 0 auto;
            padding: 0 24px;
        }

        .welcome-screen {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            text-align: center;
            padding: 40px 24px;
        }

        .welcome-logo {
            width: 64px;
            height: 64px;
            background: var(--nhs-blue);
            border-radius: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 28px;
            font-weight: 700;
            color: #fff;
            margin-bottom: 24px;
        }

        .welcome-screen h1 {
            font-size: 24px;
            font-weight: 600;
            margin-bottom: 8px;
        }

        .welcome-screen p {
            color: var(--text-secondary);
            font-size: 15px;
            max-width: 500px;
            margin-bottom: 32px;
        }

        .welcome-suggestions {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 12px;
            max-width: 920px;
            width: 100%;
            max-height: 56vh;
            overflow-y: auto;
            padding-right: 4px;
        }

        .suggestion-card {
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 14px 16px;
            text-align: left;
            cursor: pointer;
            transition: all var(--transition-fast);
            font-size: 13px;
            color: var(--text-secondary);
        }

        .suggestion-card:hover {
            border-color: var(--nhs-blue);
            background: var(--bg-tertiary);
            color: var(--text-primary);
        }

        .suggestion-card strong {
            display: block;
            color: var(--text-primary);
            margin-bottom: 4px;
            font-size: 13px;
        }

        /* Message Bubbles */
        .message-row {
            display: flex;
            margin-bottom: 24px;
            gap: 12px;
        }

        .message-row.user { justify-content: flex-end; }
        .message-row.assistant { justify-content: flex-start; }
        .message-row.system { justify-content: center; }

        .message-avatar {
            width: 32px;
            height: 32px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 13px;
            font-weight: 600;
            flex-shrink: 0;
            margin-top: 2px;
        }

        .message-row.assistant .message-avatar {
            background: var(--nhs-blue);
            color: #fff;
        }

        .message-row.user .message-avatar {
            background: var(--bg-elevated);
            color: var(--text-primary);
            border: 1px solid var(--border-color);
        }

        .message-bubble {
            max-width: 75%;
            padding: 12px 16px;
            border-radius: 12px;
            font-size: 14px;
            line-height: 1.6;
            word-break: break-word;
        }

        .message-row.user .message-bubble {
            background: var(--user-bubble);
            color: var(--text-primary);
            border-bottom-right-radius: 4px;
        }

        .message-row.assistant .message-bubble {
            background: var(--ai-bubble);
            color: var(--text-primary);
            border: 1px solid var(--border-color);
            border-bottom-left-radius: 4px;
        }

        .message-row.system .message-bubble {
            background: transparent;
            color: var(--text-muted);
            font-size: 12px;
            font-style: italic;
            padding: 4px 12px;
        }

        .message-bubble .message-meta {
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 8px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .message-row.user .message-bubble .message-meta { justify-content: flex-end; }

        .agent-badge {
            font-size: 10px;
            padding: 1px 6px;
            border-radius: 4px;
            background: rgba(0, 94, 184, 0.2);
            color: var(--nhs-blue-light);
            font-weight: 500;
        }

        .runner-badge {
            font-size: 10px;
            padding: 1px 6px;
            border-radius: 4px;
            background: rgba(210, 153, 34, 0.15);
            color: var(--warning);
            font-weight: 500;
        }

        /* Generation card within message */
        .generation-card {
            margin-top: 12px;
            background: var(--bg-primary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 12px;
        }

        .generation-card .gen-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 8px;
        }

        .generation-card .gen-title {
            font-size: 12px;
            font-weight: 600;
            color: var(--nhs-blue-light);
        }

        .generation-card .gen-status {
            font-size: 11px;
            padding: 2px 8px;
            border-radius: 4px;
            font-weight: 500;
        }

        .gen-status.preview { background: rgba(210,153,34,0.15); color: var(--warning); }
        .gen-status.approved { background: rgba(46,160,67,0.15); color: var(--success); }
        .gen-status.deployed { background: rgba(0,94,184,0.15); color: var(--nhs-blue-light); }
        .gen-status.rejected { background: rgba(248,81,73,0.15); color: var(--error); }

        .generation-card .gen-actions {
            display: flex;
            gap: 8px;
            margin-top: 10px;
        }

        .btn-approve, .btn-reject {
            padding: 5px 14px;
            border-radius: 6px;
            border: none;
            font-size: 12px;
            font-weight: 500;
            cursor: pointer;
            transition: all var(--transition-fast);
        }

        .btn-approve {
            background: var(--success);
            color: #fff;
        }

        .btn-approve:hover { background: #2c974b; }

        .btn-reject {
            background: transparent;
            color: var(--error);
            border: 1px solid var(--error);
        }

        .btn-reject:hover { background: rgba(248,81,73,0.1); }

        /* Markdown rendered content */
        .message-bubble h1, .message-bubble h2, .message-bubble h3,
        .message-bubble h4, .message-bubble h5, .message-bubble h6 {
            margin: 16px 0 8px 0;
            font-weight: 600;
        }
        .message-bubble h1 { font-size: 1.3em; }
        .message-bubble h2 { font-size: 1.15em; }
        .message-bubble h3 { font-size: 1.05em; }

        .message-bubble p { margin: 8px 0; }
        .message-bubble p:first-child { margin-top: 0; }
        .message-bubble p:last-child { margin-bottom: 0; }

        .message-bubble ul, .message-bubble ol {
            margin: 8px 0;
            padding-left: 20px;
        }

        .message-bubble li { margin: 4px 0; }

        .message-bubble pre {
            background: var(--code-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 12px 16px;
            overflow-x: auto;
            margin: 12px 0;
            font-size: 13px;
            line-height: 1.45;
        }

        .message-bubble code {
            font-family: 'Cascadia Code', 'Fira Code', 'JetBrains Mono', 'Consolas', monospace;
            font-size: 0.9em;
        }

        .message-bubble :not(pre) code {
            background: var(--bg-elevated);
            padding: 2px 6px;
            border-radius: 4px;
            border: 1px solid var(--border-color);
        }

        .message-bubble blockquote {
            border-left: 3px solid var(--nhs-blue);
            padding-left: 12px;
            margin: 8px 0;
            color: var(--text-secondary);
        }

        .message-bubble table {
            border-collapse: collapse;
            width: 100%;
            margin: 12px 0;
        }

        .message-bubble th, .message-bubble td {
            border: 1px solid var(--border-color);
            padding: 6px 12px;
            text-align: left;
            font-size: 13px;
        }

        .message-bubble th {
            background: var(--bg-elevated);
            font-weight: 600;
        }

        /* Typing Indicator */
        .typing-indicator {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 0;
        }

        .typing-dots {
            display: flex;
            gap: 4px;
            padding: 12px 16px;
            background: var(--ai-bubble);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            border-bottom-left-radius: 4px;
        }

        .typing-dots span {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--text-muted);
            animation: typing-bounce 1.4s ease-in-out infinite;
        }

        .typing-dots span:nth-child(2) { animation-delay: 0.2s; }
        .typing-dots span:nth-child(3) { animation-delay: 0.4s; }

        @keyframes typing-bounce {
            0%, 60%, 100% { transform: translateY(0); opacity: 0.4; }
            30% { transform: translateY(-6px); opacity: 1; }
        }

        /* Input Area */
        .input-area {
            padding: 16px 24px 20px;
            background: var(--bg-primary);
            border-top: 1px solid var(--border-color);
        }

        .input-wrapper {
            max-width: 800px;
            margin: 0 auto;
            position: relative;
        }

        .input-box {
            display: flex;
            align-items: flex-end;
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 4px;
            transition: border-color var(--transition-fast);
        }

        .input-box:focus-within {
            border-color: var(--nhs-blue);
        }

        .input-box textarea {
            flex: 1;
            background: transparent;
            border: none;
            outline: none;
            color: var(--text-primary);
            font-size: 14px;
            font-family: inherit;
            line-height: 1.5;
            padding: 10px 14px;
            resize: none;
            max-height: 200px;
            min-height: 24px;
        }

        .input-box textarea::placeholder { color: var(--text-muted); }

        .btn-send {
            width: 36px;
            height: 36px;
            background: var(--nhs-blue);
            color: #fff;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            margin: 2px;
            transition: all var(--transition-fast);
        }

        .btn-send:hover { background: var(--nhs-blue-dark); }

        .btn-send:disabled {
            background: var(--bg-elevated);
            color: var(--text-muted);
            cursor: not-allowed;
        }

        .input-hint {
            text-align: center;
            font-size: 11px;
            color: var(--text-muted);
            margin-top: 8px;
        }

        /* ===== Right Panel ===== */
        .right-panel {
            width: var(--right-panel-width);
            min-width: var(--right-panel-width);
            background: var(--bg-secondary);
            border-left: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            transition: margin-right var(--transition-normal), opacity var(--transition-normal);
            z-index: 20;
            overflow: hidden;
        }

        .right-panel.collapsed {
            margin-right: calc(-1 * var(--right-panel-width));
            opacity: 0;
            pointer-events: none;
        }

        .right-panel-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 14px 16px;
            border-bottom: 1px solid var(--border-color);
        }

        .right-panel-header h3 {
            font-size: 13px;
            font-weight: 600;
        }

        .panel-tabs {
            display: flex;
            border-bottom: 1px solid var(--border-color);
        }

        .panel-tab {
            flex: 1;
            padding: 10px 8px;
            text-align: center;
            font-size: 12px;
            font-weight: 500;
            color: var(--text-secondary);
            cursor: pointer;
            border-bottom: 2px solid transparent;
            transition: all var(--transition-fast);
            background: none;
            border-top: none;
            border-left: none;
            border-right: none;
        }

        .panel-tab:hover { color: var(--text-primary); }

        .panel-tab.active {
            color: var(--nhs-blue-light);
            border-bottom-color: var(--nhs-blue);
        }

        .panel-content {
            flex: 1;
            overflow-y: auto;
            padding: 16px;
        }

        /* Code Review Section */
        .review-empty {
            text-align: center;
            color: var(--text-muted);
            padding: 40px 16px;
            font-size: 13px;
        }

        .review-class {
            margin-bottom: 16px;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            overflow: hidden;
        }

        .review-class-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 10px 12px;
            background: var(--bg-tertiary);
            border-bottom: 1px solid var(--border-color);
        }

        .review-class-name {
            font-size: 12px;
            font-weight: 600;
            font-family: 'Cascadia Code', 'Fira Code', monospace;
            color: var(--nhs-blue-light);
        }

        .review-class-type {
            font-size: 10px;
            padding: 2px 6px;
            border-radius: 4px;
            background: var(--bg-elevated);
            color: var(--text-secondary);
        }

        .review-class-source {
            padding: 12px;
            background: var(--code-bg);
            font-size: 12px;
            line-height: 1.5;
            overflow-x: auto;
            white-space: pre;
            font-family: 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
            color: var(--text-primary);
            max-height: 300px;
            overflow-y: auto;
        }

        .review-actions {
            display: flex;
            gap: 8px;
            padding: 12px;
            border-top: 1px solid var(--border-color);
            background: var(--bg-tertiary);
        }

        .review-actions .btn-approve,
        .review-actions .btn-reject { flex: 1; }

        /* Production Status Section */
        .status-section {
            margin-bottom: 20px;
        }

        .status-section-title {
            font-size: 11px;
            font-weight: 600;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 10px;
        }

        .status-card {
            background: var(--bg-tertiary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 12px;
        }

        .status-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 6px 0;
        }

        .status-row:not(:last-child) {
            border-bottom: 1px solid var(--border-color);
        }

        .status-label {
            font-size: 12px;
            color: var(--text-secondary);
        }

        .status-value {
            font-size: 12px;
            font-weight: 500;
            color: var(--text-primary);
        }

        .status-value.running { color: var(--success); }
        .status-value.stopped { color: var(--error); }
        .status-value.suspended { color: var(--warning); }

        /* Runner Status Section */
        .runner-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 10px 12px;
            background: var(--bg-tertiary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            margin-bottom: 8px;
        }

        .runner-name {
            font-size: 12px;
            font-weight: 500;
            color: var(--text-primary);
        }

        .runner-model {
            font-size: 11px;
            color: var(--text-muted);
        }

        .runner-status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
        }

        .runner-status-dot.available { background: var(--success); }
        .runner-status-dot.unavailable { background: var(--error); }

        /* ===== Responsive ===== */
        @media (max-width: 1200px) {
            .right-panel { --right-panel-width: 320px; }
        }

        @media (max-width: 1024px) {
            .sidebar { --sidebar-width: 260px; }
            .right-panel {
                position: fixed;
                right: 0;
                top: 0;
                bottom: 0;
                z-index: 100;
                box-shadow: -4px 0 24px rgba(0,0,0,0.3);
            }
            .right-panel.collapsed {
                margin-right: 0;
                transform: translateX(100%);
            }
        }

        @media (max-width: 768px) {
            .sidebar {
                position: fixed;
                left: 0;
                top: 0;
                bottom: 0;
                z-index: 100;
                box-shadow: 4px 0 24px rgba(0,0,0,0.3);
            }
            .sidebar.collapsed {
                margin-left: 0;
                transform: translateX(-100%);
            }
            .welcome-suggestions {
                grid-template-columns: 1fr;
            }
            .message-bubble { max-width: 88%; }
            .conversation-title-display { max-width: 180px; }
        }

        /* ===== Overlay for mobile panels ===== */
        .panel-overlay {
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.5);
            z-index: 90;
            cursor: pointer;
        }

        /* ===== ObjectScript Syntax Highlighting ===== */
        .cos-keyword { color: #ff7b72; }
        .cos-string { color: #a5d6ff; }
        .cos-comment { color: #8b949e; font-style: italic; }
        .cos-classref { color: #d2a8ff; }
        .cos-macro { color: #7ee787; }
        .cos-number { color: #79c0ff; }
    </style>
</head>
<body>

<div class="app-container" x-data="chatApp()" x-init="init()">

    <!-- Mobile overlay when sidebar/panel is open -->
    <template x-if="showMobileOverlay">
        <div class="panel-overlay" @click="closePanels()"></div>
    </template>

    <!-- ===== LEFT SIDEBAR: Conversations ===== -->
    <aside class="sidebar" :class="{ 'collapsed': !sidebarOpen }">
        <div class="sidebar-header">
            <h2>
                <span class="logo-icon">IC</span>
                OpenLI IRIS CoPilot
            </h2>
            <button class="btn-new-chat" @click="createConversation()" :disabled="isStreaming">
                + New
            </button>
        </div>

        <div class="conversation-list">
            <template x-if="conversations.length === 0">
                <div style="text-align:center; color:var(--text-muted); padding:24px 8px; font-size:12px;">
                    No conversations yet.<br>Start a new chat to begin.
                </div>
            </template>
            <template x-for="conv in conversations" :key="conv.conversationId">
                <div class="conversation-item"
                     :class="{ 'active': currentConversationId === conv.conversationId }"
                     @click="selectConversation(conv.conversationId)">
                    <div class="conv-title" x-text="conv.title || 'New Conversation'"></div>
                    <div class="conv-meta" x-text="formatDate(conv.updatedAt || conv.createdAt)"></div>
                </div>
            </template>
        </div>

        <div class="sidebar-footer">
            IRIS AI Agent Platform &middot; <span x-text="currentNamespace"></span>
        </div>
    </aside>

    <!-- ===== MAIN CHAT AREA ===== -->
    <main class="main-area">
        <!-- Top Bar -->
        <div class="top-bar">
            <div class="top-bar-left">
                <button class="btn-icon" @click="sidebarOpen = !sidebarOpen"
                        title="Toggle sidebar">
                    &#9776;
                </button>
                <span class="conversation-title-display"
                      x-text="currentConversation ? (currentConversation.title || 'New Conversation') : 'OpenLI IRIS CoPilot'">
                </span>
            </div>
            <div class="top-bar-right">
                <div class="health-badge" :class="bridgeHealthy ? 'online' : 'offline'">
                    <span class="health-dot"></span>
                    <span x-text="bridgeHealthy ? 'Bridge Online' : 'Bridge Offline'"></span>
                </div>
                <button class="btn-icon" @click="rightPanelOpen = !rightPanelOpen"
                        title="Toggle details panel">
                    &#9881;
                </button>
            </div>
        </div>

        <!-- Messages -->
        <div class="messages-container" x-ref="messagesContainer">
            <!-- Welcome screen when no conversation selected -->
            <template x-if="!currentConversationId || (currentConversationId && messages.length === 0 && !isStreaming)">
                <div class="welcome-screen">
                    <div class="welcome-logo">IC</div>
                    <h1>OpenLI IRIS CoPilot</h1>
                    <p>Quick Queries from the real-world E2E suite. Click any tested prompt to start immediately.</p>
                    <div class="welcome-suggestions">
                        <template x-for="qq in quickQueries" :key="qq.id">
                            <div class="suggestion-card" @click="useSuggestion(qq.query)">
                                <strong x-text="qq.id + ' ' + qq.title"></strong>
                                <span x-text="qq.query"></span>
                            </div>
                        </template>
                    </div>
                </div>
            </template>

            <!-- Conversation messages -->
            <template x-if="currentConversationId && (messages.length || isStreaming)">
                <div class="messages-inner">
                    <template x-for="msg in messages" :key="msg.messageId">
                        <div class="message-row" :class="msg.role">
                            <!-- AI avatar (left) -->
                            <template x-if="msg.role === 'assistant'">
                                <div class="message-avatar">IC</div>
                            </template>

                            <!-- Bubble -->
                            <div class="message-bubble">
                                <template x-if="msg.role === 'assistant'">
                                    <div x-html="renderMarkdown(formatDisplayContent(msg.content))"></div>
                                </template>
                                <template x-if="msg.role !== 'assistant'">
                                    <div x-text="msg.content"></div>
                                </template>

                                <!-- Generation card if attached -->
                                <template x-if="msg.generationId">
                                    <div class="generation-card">
                                        <div class="gen-header">
                                            <span class="gen-title">Code Generation</span>
                                            <span class="gen-status"
                                                  :class="getGenerationStatus(msg.generationId)"
                                                  x-text="getGenerationStatus(msg.generationId)">
                                            </span>
                                        </div>
                                        <div style="font-size:12px; color:var(--text-secondary); margin-bottom:8px;"
                                             x-text="getGenerationDescription(msg.generationId)"></div>
                                        <template x-if="getGenerationStatus(msg.generationId) === 'preview'">
                                            <div class="gen-actions">
                                                <button class="btn-approve" @click="approveGeneration(msg.generationId)">
                                                    Approve &amp; Deploy
                                                </button>
                                                <button class="btn-reject" @click="rejectGeneration(msg.generationId)">
                                                    Reject
                                                </button>
                                            </div>
                                        </template>
                                    </div>
                                </template>

                                <!-- Meta -->
                                <template x-if="msg.role !== 'system'">
                                    <div class="message-meta">
                                        <span x-text="formatTime(msg.timestamp)"></span>
                                        <template x-if="msg.agentName">
                                            <span class="agent-badge" x-text="msg.agentName"></span>
                                        </template>
                                        <template x-if="msg.runnerUsed">
                                            <span class="runner-badge" x-text="msg.runnerUsed"></span>
                                        </template>
                                    </div>
                                </template>
                            </div>

                            <!-- User avatar (right) -->
                            <template x-if="msg.role === 'user'">
                                <div class="message-avatar" x-text="userInitials"></div>
                            </template>
                        </div>
                    </template>

                    <!-- Streaming message in progress -->
                    <template x-if="isStreaming && streamingContent">
                        <div class="message-row assistant">
                            <div class="message-avatar">IC</div>
                            <div class="message-bubble">
                                <div x-html="renderMarkdown(formatDisplayContent(streamingContent))"></div>
                            </div>
                        </div>
                    </template>

                    <!-- Typing indicator -->
                    <template x-if="isStreaming && !streamingContent">
                        <div class="typing-indicator">
                            <div class="message-avatar" style="background:var(--nhs-blue); color:#fff; width:32px; height:32px; border-radius:8px; display:flex; align-items:center; justify-content:center; font-size:13px; font-weight:600;">IC</div>
                            <div class="typing-dots">
                                <span></span>
                                <span></span>
                                <span></span>
                            </div>
                        </div>
                    </template>
                </div>
            </template>
        </div>

        <!-- Input Area -->
        <div class="input-area">
            <div class="input-wrapper">
                <div class="input-box">
                    <textarea x-ref="chatInput"
                              x-model="inputText"
                              @keydown.enter.prevent="handleEnter($event)"
                              @input="autoResize($event)"
                              placeholder="Describe what you want to build..."
                              rows="1"
                              :disabled="isStreaming"></textarea>
                    <button class="btn-send"
                            @click="sendMessage()"
                            :disabled="!inputText.trim() || isStreaming"
                            title="Send message">
                        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                            <path d="M14.5 1.5L7 9M14.5 1.5L10 14.5L7 9M14.5 1.5L1.5 6L7 9"
                                  stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                    </button>
                </div>
                <div class="input-hint">
                    Press <strong>Enter</strong> to send, <strong>Shift+Enter</strong> for new line
                </div>
            </div>
        </div>
    </main>

    <!-- ===== RIGHT PANEL: Details ===== -->
    <aside class="right-panel" :class="{ 'collapsed': !rightPanelOpen }">
        <div class="right-panel-header">
            <h3>Details</h3>
            <button class="btn-icon" @click="rightPanelOpen = false" style="width:28px;height:28px;font-size:14px;">
                &#10005;
            </button>
        </div>

        <!-- Tabs -->
        <div class="panel-tabs">
            <button class="panel-tab" :class="{ 'active': panelTab === 'review' }"
                    @click="panelTab = 'review'">Code Review</button>
            <button class="panel-tab" :class="{ 'active': panelTab === 'production' }"
                    @click="panelTab = 'production'">Production</button>
            <button class="panel-tab" :class="{ 'active': panelTab === 'runners' }"
                    @click="panelTab = 'runners'">Runners</button>
            <button class="panel-tab" :class="{ 'active': panelTab === 'raw' }"
                    @click="panelTab = 'raw'">Raw</button>
        </div>

        <div class="panel-content">

            <!-- Code Review Tab -->
            <template x-if="panelTab === 'review'">
                <div>
                    <template x-if="!activeGeneration">
                        <div class="review-empty">
                            No code generation to review.<br>
                            Chat with the AI to generate InterSystems classes.
                        </div>
                    </template>
                    <template x-if="activeGeneration">
                        <div>
                            <div style="margin-bottom:12px;">
                                <div style="font-size:13px; font-weight:600; margin-bottom:4px;"
                                     x-text="activeGeneration.description || 'Generated Code'"></div>
                                <div style="font-size:11px; color:var(--text-muted);">
                                    <span x-text="(activeGeneration.classes || []).length"></span> class(es) &middot;
                                    Status: <span class="gen-status" :class="activeGeneration.status"
                                                  x-text="activeGeneration.status"></span>
                                </div>
                            </div>

                            <template x-for="cls in (activeGeneration.classes || [])" :key="cls.className">
                                <div class="review-class">
                                    <div class="review-class-header">
                                        <span class="review-class-name" x-text="cls.className"></span>
                                        <span class="review-class-type" x-text="cls.classType || 'Class'"></span>
                                    </div>
                                    <div class="review-class-source" x-html="highlightCOS(cls.source || '')"></div>
                                    <template x-if="cls.compileStatus === 'error'">
                                        <div style="padding:8px 12px; font-size:12px; color:var(--error); background:rgba(248,81,73,0.08); border-top:1px solid var(--border-color);">
                                            <strong>Compile Error:</strong> <span x-text="cls.compileErrors"></span>
                                        </div>
                                    </template>
                                </div>
                            </template>

                            <template x-if="activeGeneration.status === 'preview'">
                                <div class="review-actions" style="padding:12px 0; border-top:none;">
                                    <button class="btn-approve" @click="approveGeneration(activeGeneration.generationId)">
                                        Approve &amp; Deploy All
                                    </button>
                                    <button class="btn-reject" @click="rejectGeneration(activeGeneration.generationId)">
                                        Reject All
                                    </button>
                                </div>
                            </template>
                        </div>
                    </template>
                </div>
            </template>

            <!-- Production Status Tab -->
            <template x-if="panelTab === 'production'">
                <div>
                    <div class="status-section">
                        <div class="status-section-title">Current Production</div>
                        <div class="status-card">
                            <div class="status-row">
                                <span class="status-label">Name</span>
                                <span class="status-value" x-text="productionStatus.name || 'None'"></span>
                            </div>
                            <div class="status-row">
                                <span class="status-label">Status</span>
                                <span class="status-value"
                                      :class="(productionStatus.status || '').toLowerCase()"
                                      x-text="productionStatus.status || 'Unknown'"></span>
                            </div>
                            <div class="status-row">
                                <span class="status-label">Namespace</span>
                                <span class="status-value" x-text="currentNamespace"></span>
                            </div>
                            <template x-if="productionStatus.lastStarted">
                                <div class="status-row">
                                    <span class="status-label">Started</span>
                                    <span class="status-value" x-text="formatDate(productionStatus.lastStarted)"></span>
                                </div>
                            </template>
                        </div>
                    </div>

                    <template x-if="productionStatus.hosts && productionStatus.hosts.length">
                        <div class="status-section">
                            <div class="status-section-title">Business Hosts</div>
                            <div class="status-card" style="padding:0;">
                                <template x-for="host in productionStatus.hosts" :key="host.name">
                                    <div class="status-row" style="padding:8px 12px;">
                                        <span class="status-label" x-text="host.name" style="font-size:11px; font-family:monospace;"></span>
                                        <span class="status-value" :class="(host.status || '').toLowerCase()"
                                              x-text="host.status || 'Unknown'" style="font-size:11px;"></span>
                                    </div>
                                </template>
                            </div>
                        </div>
                    </template>

                    <button class="btn-new-chat" @click="refreshProductionStatus()" style="width:100%; justify-content:center; margin-top:8px;">
                        Refresh Status
                    </button>
                </div>
            </template>

            <!-- Runners Tab -->
            <template x-if="panelTab === 'runners'">
                <div>
                    <div class="status-section-title" style="margin-bottom:12px;">Available AI Runners</div>
                    <div class="status-row" style="margin-bottom:10px;">
                        <span class="status-label">Selected Runner</span>
                        <span class="status-value" x-text="selectedRunner || 'Server Default'"></span>
                    </div>
                    <template x-if="runners.length === 0">
                        <div class="review-empty" style="padding:24px;">
                            No runners detected.<br>
                            Ensure the AI Agent Bridge is running.
                        </div>
                    </template>
                    <template x-for="runner in runners" :key="runner.id || runner.name">
                        <div class="runner-item">
                            <div>
                                <div class="runner-name" x-text="runner.name || runner.id"></div>
                                <div class="runner-model" x-text="runner.model || runner.description || ''"></div>
                            </div>
                            <div style="display:flex; align-items:center; gap:8px;">
                                <button class="btn-icon"
                                        :disabled="runner.available === false || runner.isPlaceholder"
                                        :title="runner.available === false ? 'Unavailable' : 'Use this runner'"
                                        @click="selectRunner(runner.id)"
                                        style="width:auto; padding:2px 8px; border-radius:6px;"
                                        x-text="selectedRunner === runner.id ? 'Selected' : 'Use'">
                                </button>
                                <div class="runner-status-dot"
                                     :class="runner.available !== false ? 'available' : 'unavailable'"
                                     :title="runner.available !== false ? 'Available' : 'Unavailable'">
                                </div>
                            </div>
                        </div>
                    </template>

                    <button class="btn-new-chat" @click="refreshRunners()" style="width:100%; justify-content:center; margin-top:12px;">
                        Refresh Runners
                    </button>
                </div>
            </template>

            <!-- Raw Tab -->
            <template x-if="panelTab === 'raw'">
                <div>
                    <div class="status-section-title" style="margin-bottom:12px;">Raw Stream Responses</div>
                    <template x-if="rawResponses.length === 0">
                        <div class="review-empty" style="padding:24px;">
                            No raw stream events captured yet.
                        </div>
                    </template>
                    <template x-if="rawResponses.length !== 0">
                        <div style="display:flex; flex-direction:column; gap:8px; max-height:58vh; overflow:auto;">
                            <template x-for="(evt, idx) in rawResponses" :key="idx">
                                <div style="background:#111827; color:#d1d5db; border-radius:8px; padding:8px;">
                                    <div style="font-size:11px; color:#93c5fd; margin-bottom:4px;" x-text="evt.timestamp + '  ' + evt.kind"></div>
                                    <pre style="margin:0; white-space:pre-wrap; font-size:11px;" x-text="evt.raw"></pre>
                                </div>
                            </template>
                        </div>
                    </template>
                </div>
            </template>

        </div>
    </aside>

</div>
>
    // Output JavaScript from XData block (avoids CSP &html<> bracket parsing issues)
    do ..WriteScript()
    &html<
</body>
</html>>
    quit $$$OK
}

/// Write JavaScript to the output device from XData block.
/// This avoids CSP &html<> bracket parsing issues with JS arrow functions,
/// comparison operators, and other special characters.
ClassMethod WriteScript() [ Private ]
{
    write "<script>",!
    set xdata = ##class(%Dictionary.XDataDefinition).IDKEYOpen("AIAgent.UI.Chat","ChatScript")
    if $isobject(xdata) {
        while 'xdata.Data.AtEnd {
            write xdata.Data.ReadLine(),!
        }
    }
    write "</script>",!
}

XData ChatScript [ MimeType = "application/javascript" ]
{
// ===== Marked.js Configuration =====
if (typeof marked !== 'undefined') {
    marked.setOptions({
        breaks: true,
        gfm: true,
        headerIds: false,
        mangle: false
    });
}

// ===== Alpine.js Chat Application =====
function chatApp() {
    return {
        // ----- State -----
        sidebarOpen: true,
        rightPanelOpen: false,
        panelTab: 'review',

        conversations: [],
        currentConversationId: null,
        currentConversation: null,
        messages: [],

        inputText: '',
        isStreaming: false,
        streamingContent: '',
        eventSource: null,
        rawResponses: [],

        bridgeHealthy: false,
        productionStatus: {},
        runners: [],
        selectedRunner: '',
        generations: {},

        currentNamespace: '',
        userInitials: 'U',
        quickQueries: [
            { id: 'RW01', title: 'Production topology full detail', query: 'List all production hosts with full details.' },
            { id: 'RW02', title: 'Queue depth overview', query: 'Show queue depth for all hosts.' },
            { id: 'RW03', title: 'Recent production events', query: 'Show recent production events.' },
            { id: 'RW04', title: 'Lookup table content', query: 'Show lookup table ErrorCodes content.' },
            { id: 'RW05', title: 'Class metadata query', query: 'Show metadata for class AIAgent.API.Dispatcher.' },
            { id: 'RW06', title: 'Invocation policy query', query: 'Show invocation policy.' },
            { id: 'RW07', title: 'Class catalog by package pattern', query: 'List classes in the NHSTIE2.* packages.' },
            { id: 'RW08', title: 'Dry-run add disabled host', query: 'Create a plan to add a disabled test business host named AIAgent.DryRun.TestHost, dry-run only.' },
            { id: 'RW09', title: 'Apply add host', query: 'Add a disabled test business host named AIAgent.DryRun.TestHost.' },
            { id: 'RW10', title: 'Dry-run remove host', query: 'Remove business host named AIAgent.DryRun.TestHost, dry-run only.' },
            { id: 'RW11', title: 'Platform health snapshot', query: 'Recap current platform health, active production, and runner status.' },
            { id: 'RW12', title: 'Production host names only', query: 'List all production host names only.' },
            { id: 'RW13', title: 'Disabled host inventory', query: 'Show all currently disabled business hosts.' },
            { id: 'RW14', title: 'Recent error events', query: 'Show recent production events with level ERROR in the last 60 minutes.' },
            { id: 'RW15', title: 'Queue hotspots', query: 'Which 10 hosts have the highest queue depth right now?' },
            { id: 'RW16', title: 'New interface design plan', query: 'Design an interface plan for ADT A01/A02/A03 from PAS to DrDoctor with required transforms and routing.' },
            { id: 'RW17', title: 'Existing router change plan', query: 'Create a change plan to add a new downstream operation to the current PAS router for A08 messages only.' },
            { id: 'RW18', title: 'DTL impact assessment', query: 'Assess impact of changing PID-3 mapping in the existing PAS ADT transform.' },
            { id: 'RW19', title: 'Generate operation dry-run', query: 'Create a dry-run plan for a new disabled business operation AIAgent.Generated.DrDoctor.Operation.' },
            { id: 'RW20', title: 'Generate router delta dry-run', query: 'Prepare dry-run router rule updates to route ORM messages to a new operation.' },
            { id: 'RW21', title: 'Generate with approval gate', query: 'Generate and stage required classes for a new ORU pathway; do not deploy until I approve.' },
            { id: 'RW22', title: 'Approve pending generation', query: 'Approve the latest staged generation and deploy it now.' },
            { id: 'RW23', title: 'Reject pending generation', query: 'Reject the currently staged generation and close it without deployment.' },
            { id: 'RW24', title: 'Compile validation', query: 'Compile all newly generated classes and show errors if any.' },
            { id: 'RW25', title: 'Post-deploy smoke checklist', query: 'Run post-deploy verification checklist for the new route and summarize pass/fail.' },
            { id: 'RW26', title: 'Route presence verification', query: 'Confirm the new operation is connected in router rules and currently disabled.' },
            { id: 'RW27', title: 'Message flow readiness', query: 'Validate readiness for A01/A02/A03 traffic through the new route without enabling it.' },
            { id: 'RW28', title: 'Queue spike investigation', query: 'Investigate why queue depth spiked in the last hour and identify likely bottleneck hosts.' },
            { id: 'RW29', title: 'Failed message triage', query: 'Show failed/retried message indicators for the last 2 hours and likely causes.' },
            { id: 'RW30', title: 'Runner drift check', query: 'Check whether runner health or bridge connectivity changed in the last 30 minutes.' },
            { id: 'RW31', title: 'Prepare rollback plan', query: 'Prepare rollback plan to previous stable version for the latest deployment, no execution.' },
            { id: 'RW32', title: 'Execute rollback', query: 'Rollback to the previous stable snapshot now.' },
            { id: 'RW33', title: 'Audit trail by conversation', query: 'Show the audit trail for this conversation including requested actions and outcomes.' },
            { id: 'RW34', title: 'CAB ready summary', query: 'Produce CAB-ready summary of planned/applied integration changes and risks.' },
            { id: 'RW35', title: 'Add multiple hosts demo', query: 'Add disabled business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC.' },
            { id: 'RW36', title: 'Edit multiple hosts demo', query: 'Update business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC set Enabled=0.' },
            { id: 'RW37', title: 'Remove multiple hosts demo', query: 'Remove business operations named AIAgent.Demo.OpA, AIAgent.Demo.OpB and AIAgent.Demo.OpC.' }
        ],

        // ----- Computed -----
        get showMobileOverlay() {
            if (window.innerWidth > 1024) return false;
            return (this.sidebarOpen || this.rightPanelOpen);
        },

        get activeGeneration() {
            let active = null;
            for (const msg of this.messages) {
                if (msg.generationId && this.generations[msg.generationId]) {
                    const gen = this.generations[msg.generationId];
                    if (!active || gen.status === 'preview') {
                        active = gen;
                    }
                }
            }
            return active;
        },

        // ----- Initialization -----
        async init() {
            this.currentNamespace = this.getNamespaceFromUrl();
            this.userInitials = this.getUserInitials();
            try { this.selectedRunner = localStorage.getItem('aiagent.selectedRunner') || ''; } catch (e) {}
            this.currentConversationId = this.getStoredConversationId();

            await Promise.allSettled([
                this.loadConversations(),
                this.checkHealth(),
                this.refreshRunners()
            ]);
            await this.restoreConversationAfterRefresh();

            // Periodic health check (30 minutes to reduce runner probe traffic)
            setInterval(() => { this.checkHealth(); }, 1800000);

            // Focus the input
            this.$nextTick(() => {
                if (this.$refs.chatInput) this.$refs.chatInput.focus();
            });
        },

        getNamespaceFromUrl() {
            const path = window.location.pathname;
            const match = path.match(/\/csp\/([^\/]+)\//i);
            return match ? match[1].toUpperCase() : 'USER';
        },

        getUserInitials() {
            return 'U';
        },

        // ----- API Helpers -----
        getBaseUrl() {
            return '/ai';
        },

        async apiFetch(path, options = {}) {
            const url = this.getBaseUrl() + path;
            const defaults = {
                headers: { 'Content-Type': 'application/json' }
            };
            const config = { ...defaults, ...options };
            if (config.body && typeof config.body === 'object') {
                config.body = JSON.stringify(config.body);
            }
            try {
                const response = await fetch(url, config);
                if (!response.ok) {
                    const text = await response.text();
                    throw new Error('HTTP ' + response.status + ': ' + text);
                }
                return await response.json();
            } catch (err) {
                console.error('API error:', path, err);
                throw err;
            }
        },

        unwrapApi(result) {
            if (result && typeof result === 'object' && Object.prototype.hasOwnProperty.call(result, 'data')) {
                return result.data;
            }
            return result;
        },

        getStoredConversationId() {
            try { return localStorage.getItem('aiagent.currentConversationId') || ''; } catch (e) {}
            return '';
        },

        storeConversationId(id) {
            try {
                if (id) localStorage.setItem('aiagent.currentConversationId', id);
                else localStorage.removeItem('aiagent.currentConversationId');
            } catch (e) {}
        },

        // ----- Conversations -----
        async loadConversations() {
            try {
                const result = await this.apiFetch('/conversations');
                const payload = this.unwrapApi(result);
                if (Array.isArray(payload)) {
                    this.conversations = payload;
                } else if (payload && Array.isArray(payload.data)) {
                    this.conversations = payload.data;
                } else {
                    this.conversations = [];
                }
            } catch (err) {
                console.error('Failed to load conversations:', err);
                this.conversations = [];
            }
        },

        async restoreConversationAfterRefresh() {
            if (!Array.isArray(this.conversations) || this.conversations.length === 0) return;
            const savedId = this.currentConversationId || this.getStoredConversationId();
            if (savedId && this.conversations.some(c => c.conversationId === savedId)) {
                await this.selectConversation(savedId);
                return;
            }
            await this.selectConversation(this.conversations[0].conversationId);
        },

        async selectConversation(id) {
            if (this.isStreaming) return;
            this.currentConversationId = id;
            this.storeConversationId(id);
            this.messages = [];
            this.streamingContent = '';
            this.rawResponses = [];
            this.generations = {};

            try {
                const result = await this.apiFetch('/conversations/' + id);
                const payload = this.unwrapApi(result) || {};
                this.currentConversation = payload.conversation || payload;
                this.messages = payload.messages || [];

                for (const msg of this.messages) {
                    if (msg.generationId && !this.generations[msg.generationId]) {
                        await this.loadGeneration(msg.generationId);
                    }
                }
            } catch (err) {
                console.error('Failed to load conversation:', err);
            }

            this.scrollToBottom();
            this.closePanels();

            this.$nextTick(() => {
                if (this.$refs.chatInput) this.$refs.chatInput.focus();
            });
        },

        async createConversation() {
            if (this.isStreaming) return;
            try {
                const result = await this.apiFetch('/conversations', {
                    method: 'POST',
                    body: { title: '', targetNamespace: this.currentNamespace }
                });
                const payload = this.unwrapApi(result) || {};
                const conv = payload.conversation || payload;
                if (conv && conv.conversationId) {
                    this.conversations.unshift(conv);
                    this.currentConversationId = conv.conversationId;
                    this.storeConversationId(conv.conversationId);
                    this.currentConversation = conv;
                    this.messages = [];
                    this.generations = {};
                    this.streamingContent = '';
                }
            } catch (err) {
                console.error('Failed to create conversation:', err);
            }

            this.$nextTick(() => {
                if (this.$refs.chatInput) this.$refs.chatInput.focus();
            });
        },

        async loadGeneration(generationId) {
            try {
                const result = await this.apiFetch('/generations/' + generationId);
                const payload = this.unwrapApi(result) || {};
                const gen = payload.generation || payload;
                if (gen) {
                    this.generations[generationId] = gen;
                }
            } catch (err) {
                console.error('Failed to load generation:', err);
            }
        },

        // ----- Messaging -----
        handleEnter(event) {
            if (event.shiftKey) {
                const ta = event.target;
                const start = ta.selectionStart;
                const end = ta.selectionEnd;
                this.inputText = this.inputText.substring(0, start) + '\n' + this.inputText.substring(end);
                this.$nextTick(() => {
                    ta.selectionStart = ta.selectionEnd = start + 1;
                    this.autoResize({ target: ta });
                });
                return;
            }
            this.sendMessage();
        },

        async sendMessage() {
            const text = this.inputText.trim();
            if (!text || this.isStreaming) return;

            if (!this.currentConversationId) {
                await this.createConversation();
                if (!this.currentConversationId) return;
            }

            const userMsg = {
                messageId: 'temp-' + Date.now(),
                conversationId: this.currentConversationId,
                role: 'user',
                content: text,
                timestamp: new Date().toISOString()
            };
            this.messages.push(userMsg);
            this.inputText = '';

            if (this.$refs.chatInput) {
                this.$refs.chatInput.style.height = 'auto';
            }

            this.scrollToBottom();

            this.isStreaming = true;
            this.streamingContent = '';
            this.rawResponses = [];

            try {
                const streamUrl = this.getBaseUrl() + '/chat/stream';
                const body = JSON.stringify({
                    conversationId: this.currentConversationId,
                    message: text,
                    namespace: this.currentNamespace,
                    preferredRunner: this.selectedRunner || undefined
                });

                const response = await fetch(streamUrl, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: body
                });

                if (!response.ok) {
                    throw new Error('Stream request failed: HTTP ' + response.status);
                }

                const reader = response.body.getReader();
                const decoder = new TextDecoder();
                let buffer = '';
                let assistantMsg = null;

                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;

                    buffer += decoder.decode(value, { stream: true });
                    const lines = buffer.split('\n');
                    buffer = lines.pop() || '';

                    for (const line of lines) {
                        if (line.startsWith('data: ')) {
                            const jsonStr = line.substring(6).trim();
                            if (jsonStr === '[DONE]') {
                                continue;
                            }
                            try {
                                const chunk = JSON.parse(jsonStr);
                                this.captureRawResponse('sse-json', jsonStr);

                                if (chunk.token) {
                                    this.streamingContent += chunk.token;
                                    this.scrollToBottom();
                                }

                                if (chunk.response && !this.streamingContent) {
                                    this.streamingContent += chunk.response;
                                    this.scrollToBottom();
                                }
                                if (chunk.finalResponse) {
                                    this.streamingContent = chunk.finalResponse;
                                    this.scrollToBottom();
                                }

                                if (chunk.runner) {
                                    if (!assistantMsg) assistantMsg = {};
                                    assistantMsg.runner = chunk.runner;
                                }

                                if (chunk.error) {
                                    this.streamingContent += '\n\n**Error:** ' + chunk.error;
                                }

                                if (chunk.messageId) {
                                    assistantMsg = chunk;
                                }

                                if (chunk.generationId) {
                                    await this.loadGeneration(chunk.generationId);
                                    if (assistantMsg) {
                                        assistantMsg.generationId = chunk.generationId;
                                    }
                                }
                            } catch (parseErr) {
                                this.captureRawResponse('sse-raw', jsonStr);
                            }
                        }
                    }
                }

                if (this.streamingContent && this.streamingContent.trim()) {
                    const finalMsg = {
                        messageId: (assistantMsg && assistantMsg.messageId) || ('ai-' + Date.now()),
                        conversationId: this.currentConversationId,
                        role: 'assistant',
                        content: this.streamingContent,
                        timestamp: new Date().toISOString(),
                        agentName: assistantMsg ? assistantMsg.agent : '',
                        runnerUsed: assistantMsg ? assistantMsg.runner : (this.selectedRunner || ''),
                        generationId: assistantMsg ? assistantMsg.generationId : ''
                    };
                    this.messages.push(finalMsg);

                    if (finalMsg.generationId) {
                        this.panelTab = 'review';
                        this.rightPanelOpen = true;
                    }
                } else {
                    this.messages.push({
                        messageId: 'sys-' + Date.now(),
                        conversationId: this.currentConversationId,
                        role: 'system',
                        content: 'No response payload was returned from the stream.',
                        timestamp: new Date().toISOString()
                    });
                }

                if (this.currentConversation &&
                    (!this.currentConversation.title || this.currentConversation.title === 'New Conversation')) {
                    this.currentConversation.title = text.substring(0, 100);
                    const idx = this.conversations.findIndex(c => c.conversationId === this.currentConversationId);
                    if (idx !== -1) {
                        this.conversations[idx].title = this.currentConversation.title;
                    }
                }

            } catch (err) {
                console.error('Stream error:', err);
                this.messages.push({
                    messageId: 'err-' + Date.now(),
                    conversationId: this.currentConversationId,
                    role: 'system',
                    content: 'Connection error: ' + err.message,
                    timestamp: new Date().toISOString()
                });
            } finally {
                this.isStreaming = false;
                this.streamingContent = '';
                await this.reloadCurrentConversation();
                this.scrollToBottom();
                this.$nextTick(() => {
                    if (this.$refs.chatInput) this.$refs.chatInput.focus();
                });
            }
        },

        async reloadCurrentConversation() {
            if (!this.currentConversationId) return;
            try {
                const result = await this.apiFetch('/conversations/' + this.currentConversationId);
                const payload = this.unwrapApi(result) || {};
                this.currentConversation = payload.conversation || payload;
                this.messages = payload.messages || [];
            } catch (err) {
                console.error('Failed to reload conversation:', err);
            }
        },

        captureRawResponse(kind, raw) {
            this.rawResponses.push({
                timestamp: new Date().toLocaleTimeString(),
                kind: kind || 'raw',
                raw: String(raw || '')
            });
            if (this.rawResponses.length > 200) {
                this.rawResponses = this.rawResponses.slice(this.rawResponses.length - 200);
            }
        },

        useSuggestion(text) {
            this.inputText = text;
            this.$nextTick(() => {
                this.sendMessage();
            });
        },

        // ----- Code Generation Actions -----
        async approveGeneration(generationId) {
            try {
                const result = await this.apiFetch('/generate/approve', {
                    method: 'POST',
                    body: { generationId: generationId }
                });

                await this.loadGeneration(generationId);

                const gen = this.generations[generationId];
                const statusText = (result.success || (gen && gen.status === 'deployed'))
                    ? 'Code generation approved and deployed successfully.'
                    : 'Code generation approved. ' + (result.message || '');

                this.messages.push({
                    messageId: 'sys-' + Date.now(),
                    conversationId: this.currentConversationId,
                    role: 'system',
                    content: statusText,
                    timestamp: new Date().toISOString()
                });

                this.scrollToBottom();
                this.refreshProductionStatus();
            } catch (err) {
                console.error('Approve failed:', err);
                this.messages.push({
                    messageId: 'err-' + Date.now(),
                    conversationId: this.currentConversationId,
                    role: 'system',
                    content: 'Approval failed: ' + err.message,
                    timestamp: new Date().toISOString()
                });
            }
        },

        async rejectGeneration(generationId) {
            try {
                await this.apiFetch('/generate/reject', {
                    method: 'POST',
                    body: { generationId: generationId }
                });

                await this.loadGeneration(generationId);

                this.messages.push({
                    messageId: 'sys-' + Date.now(),
                    conversationId: this.currentConversationId,
                    role: 'system',
                    content: 'Code generation rejected.',
                    timestamp: new Date().toISOString()
                });

                this.scrollToBottom();
            } catch (err) {
                console.error('Reject failed:', err);
            }
        },

        // ----- Health / Status -----
        async checkHealth() {
            try {
                const result = await this.apiFetch('/health');
                const payload = this.unwrapApi(result) || {};
                this.bridgeHealthy = !!(payload.healthy || payload.bridgeHealthy || result.status === 'ok');
                if (payload.namespace) this.currentNamespace = payload.namespace;
                if (payload.production) this.productionStatus = payload.production;
            } catch (err) {
                this.bridgeHealthy = false;
            }
        },

        async refreshProductionStatus() {
            try {
                const result = await this.apiFetch('/health');
                const payload = this.unwrapApi(result) || {};
                if (payload.production) {
                    this.productionStatus = payload.production;
                }
            } catch (err) {
                console.error('Failed to refresh production status:', err);
            }
        },

        async refreshRunners() {
            try {
                const result = await this.apiFetch('/runners');
                const payload = this.unwrapApi(result);
                this.runners = this.normalizeRunners(payload);
                this.ensureSelectedRunner();
            } catch (err) {
                console.error('Failed to load runners:', err);
                this.runners = [];
            }
        },

        normalizeRunners(payload) {
            const raw = Array.isArray(payload) ? payload : [];
            const runners = raw.map((r) => {
                const available = !!(r && r.health && r.health.healthy);
                return {
                    id: r.id || '',
                    name: r.name || r.id || 'Unknown',
                    model: (r.health && r.health.model) || '',
                    available: available,
                    isPlaceholder: false
                };
            });
            const ids = new Set(runners.map(r => r.id));
            if (!ids.has('azure-openai-codex')) {
                runners.push({ id: 'azure-openai-codex', name: 'Azure OpenAI Codex', model: 'Coming soon', available: false, isPlaceholder: true });
            }
            if (!ids.has('google-gemini')) {
                runners.push({ id: 'google-gemini', name: 'Google Gemini', model: 'Coming soon', available: false, isPlaceholder: true });
            }
            return runners;
        },

        ensureSelectedRunner() {
            if (!this.selectedRunner) return;
            const exists = this.runners.some(r => r.id === this.selectedRunner && !r.isPlaceholder);
            if (!exists) {
                this.selectedRunner = '';
                try { localStorage.removeItem('aiagent.selectedRunner'); } catch (e) {}
            }
        },

        selectRunner(runnerId) {
            this.selectedRunner = runnerId || '';
            try { localStorage.setItem('aiagent.selectedRunner', this.selectedRunner); } catch (e) {}
        },

        // ----- Generation Helpers -----
        getGenerationStatus(generationId) {
            const gen = this.generations[generationId];
            return gen ? gen.status : 'preview';
        },

        getGenerationDescription(generationId) {
            const gen = this.generations[generationId];
            if (!gen) return '';
            const count = (gen.classes || []).length;
            return (gen.description || 'Generated code') + ' (' + count + ' class' + (count !== 1 ? 'es' : '') + ')';
        },

        // ----- Rendering Helpers -----
        renderMarkdown(text) {
            if (!text) return '';
            try {
                if (typeof marked !== 'undefined' && marked.parse) {
                    return marked.parse(text);
                }
            } catch (err) {
                console.error('Markdown rendering error:', err);
            }
            return this.escapeHtml(text).replace(/\n/g, '<br>');
        },

        formatDisplayContent(text) {
            if (!text || typeof text !== 'string') return text || '';
            const trimmed = text.trim();
            if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
                try {
                    const parsed = JSON.parse(trimmed);
                    if (parsed && typeof parsed.response === 'string' && parsed.response.trim()) {
                        return parsed.response;
                    }
                } catch (e) {}
            }
            return text;
        },

        escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        },

        highlightCOS(source) {
            if (!source) return '';
            let html = this.escapeHtml(source);

            // Line comments
            html = html.replace(/(\/\/.*$)/gm, '<span class="cos-comment">$1</span>');
            // Semicolon comments
            html = html.replace(/(;[^"]*$)/gm, (match) => {
                if (match.indexOf('cos-string') === -1) {
                    return '<span class="cos-comment">' + match + '</span>';
                }
                return match;
            });

            // Strings
            html = html.replace(/(&quot;[^&]*?&quot;)/g, '<span class="cos-string">$1</span>');

            // Macros
            html = html.replace(/(\$\$\$\w+)/g, '<span class="cos-macro">$1</span>');

            // System functions and variables
            html = html.replace(/(\$\w+)/g, '<span class="cos-number">$1</span>');

            // Class references
            html = html.replace(/(##class\([^)]*\))/gi, '<span class="cos-classref">$1</span>');

            // Keywords
            const keywords = [
                'Class', 'Extends', 'Property', 'Parameter', 'Method', 'ClassMethod',
                'As', 'set', 'do', 'if', 'else', 'elseif', 'while', 'for', 'quit',
                'return', 'try', 'catch', 'throw', 'continue', 'new', 'kill',
                'write', 'read', 'open', 'close', 'use', 'lock', 'unlock',
                'Index', 'ForeignKey', 'Trigger', 'Query', 'Storage',
                'Private', 'Abstract', 'Final', 'Required', 'Unique',
                'Relationship', 'SqlProc', 'SqlQuery', 'WebMethod'
            ];
            const kwPattern = new RegExp('\\b(' + keywords.join('|') + ')\\b', 'g');
            html = html.replace(kwPattern, '<span class="cos-keyword">$1</span>');

            return html;
        },

        // ----- Date/Time Formatting -----
        formatDate(dateStr) {
            if (!dateStr) return '';
            try {
                const d = new Date(dateStr);
                const now = new Date();
                const diffMs = now - d;
                const diffMins = Math.floor(diffMs / 60000);

                if (diffMins < 1) return 'Just now';
                if (diffMins < 60) return diffMins + 'm ago';
                const diffHours = Math.floor(diffMins / 60);
                if (diffHours < 24) return diffHours + 'h ago';
                const diffDays = Math.floor(diffHours / 24);
                if (diffDays < 7) return diffDays + 'd ago';

                return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
            } catch (e) {
                return dateStr;
            }
        },

        formatTime(dateStr) {
            if (!dateStr) return '';
            try {
                const d = new Date(dateStr);
                return d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
            } catch (e) {
                return dateStr;
            }
        },

        // ----- UI Helpers -----
        autoResize(event) {
            const ta = event.target;
            ta.style.height = 'auto';
            ta.style.height = Math.min(ta.scrollHeight, 200) + 'px';
        },

        scrollToBottom() {
            this.$nextTick(() => {
                var container = this.$refs.messagesContainer;
                if (container) {
                    container.scrollTop = container.scrollHeight;
                }
            });
        },

        closePanels() {
            if (window.innerWidth <= 1024) {
                this.rightPanelOpen = false;
            }
            if (window.innerWidth <= 768) {
                this.sidebarOpen = false;
            }
        }
    };
}
}

}

