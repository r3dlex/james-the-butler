# Chrome Extension Specification

For the full platform specification, see [platform.md](platform.md) §22, §22.4, §25.

## Purpose

The Chrome extension (`james-chrome`) provides a sidebar panel for controlling James the Butler sessions while browsing. It integrates with the CDP-controlled Chrome instance used for Browser Control, offering session management, tab awareness, and inline approval for Confirmed mode actions.

## Repository

- **Repository**: `james-chrome` (separate repo, not part of the monorepo)
- **Technology**: TypeScript, Manifest V3 (Chrome Extensions)
- **Distribution**: Sideloaded into the CDP-controlled Chrome instance. NOT distributed via Chrome Web Store (out of scope for v1.0).

## Scope

The extension runs exclusively inside the Chrome instance that James controls via Chrome DevTools Protocol (CDP). It is not designed for general-purpose browsing in uncontrolled Chrome installations.

## Authentication

- **Flow**: OAuth 2.0 Device Code Flow (see [security.md](security.md))
- **Frequency**: One-time per installation. Refresh tokens persist in extension storage.
- **Binding**: Device code ties the extension to the user's James account, same flow as Office add-ins.

## Sidebar Panel

The extension uses the Chrome Side Panel API (`chrome.sidePanel`) as its primary UI surface.

| Section              | Description                                                  |
|----------------------|--------------------------------------------------------------|
| Session conversation | Full chat interface with streaming responses                 |
| Active tab group     | Current tab group name, list of tabs with titles and favicons|
| Task status          | Planner task list with live status from the backend          |
| Token cost           | Running token usage for the active session                   |
| Execution mode       | Direct / Confirmed toggle                                   |

## Tab Group Integration

- Displays the current tab group managed by the CDP session
- Allows basic tab management: switch active tab, close tabs, view tab URLs
- Tab context (URL, title, selection) is sent to the backend as session context

## Execution Modes

| Mode      | Behavior                                                              |
|-----------|-----------------------------------------------------------------------|
| Direct    | Browser actions execute immediately via CDP                           |
| Confirmed | Inline approval panel appears in the sidebar before each action. User sees action description, target element, and expected outcome. Approve or reject per action. |

## Communication

| Channel   | Purpose                                  | Protocol         |
|-----------|------------------------------------------|------------------|
| REST      | Session management, auth                 | HTTPS to backend |
| WebSocket | Streaming responses, live status, CDP events | Phoenix channels |

The extension connects to the Phoenix backend using the same WebSocket infrastructure as all other clients. CDP events (navigation, page load, errors) are relayed through the backend, not directly from the browser.

## Key Constraints

- Manifest V3 service workers have a limited lifetime; the extension must handle worker restarts gracefully
- No access to `chrome.debugger` from the extension itself — all CDP interaction goes through the backend
- Extension storage (`chrome.storage.local`) is used for auth tokens and preferences only
- Content scripts are minimal — the sidebar panel handles all UI
