# WebRTC Streaming Specification

For the full platform specification, see [platform.md](platform.md) SS4.3, SS12, SS21.2, SS21.3, SS21.6.
For mobile client details, see [flutter.md](flutter.md).

---

## Purpose

Live video streaming of desktop control and browser control sessions to web, desktop, and mobile viewers. Enables real-time observation of agent activity without polling for screenshots.

---

## Protocol

WebRTC peer connections between host (capture source) and viewers (frontend clients).

| Component | Technology |
|-----------|-----------|
| Video codec | H.264 with adaptive resolution |
| Signaling | Phoenix Channels (WebSocket) for SDP offer/answer exchange |
| ICE | STUN server bundled with Phoenix deployment |
| NAT traversal | TURN relay co-located with backend for firewalled networks |
| Mobile client | `flutter_webrtc` plugin |

---

## Capture Sources

### Linux (Desktop Control)

PipeWire captures Wayland compositor output. The capture daemon runs as a systemd user service managed by OpenClaw.

```
Wayland Compositor --> PipeWire --> GStreamer pipeline --> WebRTC
```

### macOS (Desktop Control)

Screen Capture API (`CGDisplayStream`) via a launchd daemon managed by OpenClaw.

```
CGDisplayStream --> VideoToolbox (H.264) --> WebRTC
```

### Browser Control (CDP)

Browser sessions use CDP `Page.captureScreenshot` for the agent vision loop (not streamed). The browser window itself is captured by the platform-level screen capture above when a viewer connects.

---

## Signaling Flow

1. Viewer joins `session:<id>` Phoenix Channel.
2. Viewer sends `webrtc:offer` with SDP offer.
3. Host receives offer via Channel, creates SDP answer.
4. Host sends `webrtc:answer` back through Channel.
5. ICE candidates exchanged via `webrtc:ice_candidate` messages.
6. Peer connection established; media flows directly between host and viewer.

---

## Adaptive Bitrate

Resolution and bitrate adjust dynamically based on network conditions.

| Network | Resolution | Bitrate | Frame Rate |
|---------|-----------|---------|------------|
| Local (< 5ms RTT) | 1920x1080 | 4 Mbps | 30 fps |
| LAN (< 20ms RTT) | 1280x720 | 2 Mbps | 24 fps |
| WAN (< 100ms RTT) | 854x480 | 1 Mbps | 15 fps |
| Poor (> 100ms RTT) | 640x360 | 500 Kbps | 10 fps |

**Latency targets:**
- Local network: sub-second end-to-end
- WAN: under 2 seconds end-to-end

---

## View Mode Integration

See [platform.md](platform.md) SS12 for View Mode layout.

- **Single session:** Live stream embedded in the session view right panel.
- **Multi-agent view:** Thumbnail grid of active streams. Click to expand to full-size viewer with controls overlay.
- **Mobile:** Full-screen landscape viewer with tap-to-interact overlay.

---

## Debug Mode (SS21.6)

Agent can optionally consume its own live WebRTC stream as a vision input instead of periodic CDP screenshots. Useful for tasks requiring continuous visual feedback (e.g. monitoring animations, video playback verification).

Enabled per-session via `vision_source: "stream"` in session config. Default is `vision_source: "screenshot"`.

---

## Security

- WebRTC streams are authenticated: only users with session access can join as viewers.
- DTLS-SRTP encryption on all media channels (WebRTC default).
- TURN credentials are short-lived, rotated per session.
