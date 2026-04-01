# Office Add-ins Specification

For the full platform specification, see [platform.md](platform.md) §4.4, §4.5, §3, §25.

## Purpose

The Office add-ins (`james-office`) embed James the Butler into Microsoft Word, Excel, and PowerPoint as a sidebar task panel. Users interact with sessions, approve changes, and leverage document context without leaving their Office application.

## Repository

- **Repository**: `james-office` (separate repo, not part of the monorepo)
- **Technology**: Office.js, TypeScript, Manifest V3
- **Supported Apps**: Word, Excel, PowerPoint (desktop and web)

## Authentication

- **Flow**: OAuth 2.0 Device Code Flow (see [security.md](security.md))
- **Frequency**: One-time per installation. Refresh tokens persist across sessions.
- **Binding**: Device code ties the add-in installation to the user's James account.

## Document Context

Progressive retrieval strategy — the add-in extracts document content in semantic chunks and indexes it via the backend `/embeddings` endpoint for semantic search.

| App        | Chunk Unit           | Retrieval Strategy                              |
|------------|----------------------|-------------------------------------------------|
| Word       | Paragraph            | Iterate paragraphs via `Body.paragraphs`        |
| Excel      | Named range / Sheet  | Named ranges first, then sheet-level scan       |
| PowerPoint | Slide                | Slide-by-slide via `Presentation.slides`        |

Chunks are embedded on first load and incrementally re-indexed on document change events. The backend stores embeddings per-session for context retrieval during conversation.

## Task Panel (Sidebar)

The sidebar is the primary UI surface inside Office.

- **Session conversation**: Full chat interface embedded in the Office task pane
- **Execution mode toggle**: Direct / Confirmed, visible at the top of the sidebar
- **Token counter**: Running cost for the active session
- **Document context indicator**: Shows indexed chunk count and last sync time

## Execution Modes

| Mode      | Behavior                                                                 |
|-----------|--------------------------------------------------------------------------|
| Direct    | Changes applied immediately. Native undo (Ctrl+Z) serves as safety net. |
| Confirmed | Structured diff shown at paragraph (Word), cell range (Excel), or slide (PowerPoint) level. User approves or rejects each change before application. |

In Confirmed mode, diffs are rendered inline in the sidebar with accept/reject controls per change unit.

## Communication

| Channel   | Purpose                                  | Protocol         |
|-----------|------------------------------------------|------------------|
| REST      | Session management, embeddings, auth     | HTTPS to backend |
| WebSocket | Streaming responses, live status updates | Phoenix channels |

The add-in connects to the Phoenix backend via the same WebSocket infrastructure used by the web frontend. Reconnection logic follows exponential backoff with jitter.

## Key Constraints

- Office.js API limits vary by host (Word, Excel, PowerPoint) and platform (desktop vs. web)
- Add-in must degrade gracefully when running in Office on the web (reduced API surface)
- All document modifications go through Office.js APIs to preserve native undo stack
- No local agent execution — all processing happens on the backend
