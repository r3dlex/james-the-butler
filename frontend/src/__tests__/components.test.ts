// @vitest-environment happy-dom
import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";

vi.mock("../services/api", () => ({
  api: { setToken: vi.fn(), get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));
vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

// ---------------------------------------------------------------------------
// EmptyState
// ---------------------------------------------------------------------------
describe("EmptyState", () => {
  it("renders message prop", async () => {
    const { default: EmptyState } =
      await import("../components/common/EmptyState.vue");
    const wrapper = mount(EmptyState, {
      props: { message: "Nothing here yet" },
    });
    expect(wrapper.text()).toContain("Nothing here yet");
  });

  it("renders icon slot content", async () => {
    const { default: EmptyState } =
      await import("../components/common/EmptyState.vue");
    const wrapper = mount(EmptyState, {
      props: { message: "Empty" },
      slots: { icon: "<span class='icon-slot'>★</span>" },
    });
    expect(wrapper.find(".icon-slot").exists()).toBe(true);
  });

  it("renders action slot content", async () => {
    const { default: EmptyState } =
      await import("../components/common/EmptyState.vue");
    const wrapper = mount(EmptyState, {
      props: { message: "Empty" },
      slots: { action: "<button>Create One</button>" },
    });
    expect(wrapper.find("button").text()).toBe("Create One");
  });
});

// ---------------------------------------------------------------------------
// LoadingSpinner
// ---------------------------------------------------------------------------
describe("LoadingSpinner", () => {
  it("renders without errors with default props", async () => {
    const { default: LoadingSpinner } =
      await import("../components/common/LoadingSpinner.vue");
    const wrapper = mount(LoadingSpinner);
    expect(wrapper.exists()).toBe(true);
  });

  it("renders with size prop", async () => {
    const { default: LoadingSpinner } =
      await import("../components/common/LoadingSpinner.vue");
    const wrapper = mount(LoadingSpinner, { props: { size: "lg" } });
    expect(wrapper.exists()).toBe(true);
  });

  it("renders with fullPage prop", async () => {
    const { default: LoadingSpinner } =
      await import("../components/common/LoadingSpinner.vue");
    const wrapper = mount(LoadingSpinner, { props: { fullPage: true } });
    expect(wrapper.exists()).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// RiskBadge
// ---------------------------------------------------------------------------
describe("RiskBadge", () => {
  it("renders 'Read Only' label for read_only level", async () => {
    const { default: RiskBadge } =
      await import("../components/common/RiskBadge.vue");
    const wrapper = mount(RiskBadge, { props: { level: "read_only" } });
    expect(wrapper.text()).toBe("Read Only");
  });

  it("renders 'Additive' label for additive level", async () => {
    const { default: RiskBadge } =
      await import("../components/common/RiskBadge.vue");
    const wrapper = mount(RiskBadge, { props: { level: "additive" } });
    expect(wrapper.text()).toBe("Additive");
  });

  it("renders 'Destructive' label for destructive level", async () => {
    const { default: RiskBadge } =
      await import("../components/common/RiskBadge.vue");
    const wrapper = mount(RiskBadge, { props: { level: "destructive" } });
    expect(wrapper.text()).toBe("Destructive");
  });

  it("is a span element", async () => {
    const { default: RiskBadge } =
      await import("../components/common/RiskBadge.vue");
    const wrapper = mount(RiskBadge, { props: { level: "read_only" } });
    expect(wrapper.element.tagName.toLowerCase()).toBe("span");
  });
});

// ---------------------------------------------------------------------------
// StatusBadge
// ---------------------------------------------------------------------------
describe("StatusBadge", () => {
  const cases = [
    "active",
    "running",
    "idle",
    "pending",
    "completed",
    "blocked",
    "failed",
    "error",
    "online",
    "offline",
    "degraded",
    "connected",
    "disconnected",
  ];

  for (const status of cases) {
    it(`renders capitalised label for status '${status}'`, async () => {
      const { default: StatusBadge } =
        await import("../components/common/StatusBadge.vue");
      const wrapper = mount(StatusBadge, { props: { status } });
      const expected = status.charAt(0).toUpperCase() + status.slice(1);
      expect(wrapper.text()).toContain(expected);
    });
  }

  it("renders for unknown status without crashing", async () => {
    const { default: StatusBadge } =
      await import("../components/common/StatusBadge.vue");
    const wrapper = mount(StatusBadge, { props: { status: "mystery" } });
    expect(wrapper.text()).toContain("Mystery");
  });
});

// ---------------------------------------------------------------------------
// TokenDisplay
// ---------------------------------------------------------------------------
describe("TokenDisplay", () => {
  it("renders without errors with token count and cost", async () => {
    const { default: TokenDisplay } =
      await import("../components/common/TokenDisplay.vue");
    const wrapper = mount(TokenDisplay, {
      props: { tokens: 150, cost: 0.01 },
    });
    expect(wrapper.exists()).toBe(true);
    expect(wrapper.text()).toContain("tokens");
  });
});

// ---------------------------------------------------------------------------
// MessageBubble
// ---------------------------------------------------------------------------
// Minimal valid Message fixture for component tests.
// Import ContentBlockType so we can keep the fixture fully typed.
import type { ContentBlockType } from "../types/message";

const makeTestMessage = (
  id: string,
  role: "user" | "assistant",
  type: ContentBlockType,
  text: string,
) => ({
  id,
  sessionId: "sess-test",
  role,
  content: [{ type, text }],
  attachments: [],
  tokenCount: 0,
  createdAt: new Date().toISOString(),
});

describe("MessageBubble", () => {
  it("renders user message", async () => {
    const { default: MessageBubble } =
      await import("../components/session/MessageBubble.vue");
    const message = makeTestMessage("m1", "user", "text", "Hello there");
    const wrapper = mount(MessageBubble, { props: { message } });
    expect(wrapper.text()).toContain("You");
  });

  it("renders assistant message", async () => {
    const { default: MessageBubble } =
      await import("../components/session/MessageBubble.vue");
    const message = makeTestMessage(
      "m2",
      "assistant",
      "text",
      "I can help with that.",
    );
    const wrapper = mount(MessageBubble, { props: { message } });
    expect(wrapper.text()).toContain("James");
  });

  it("renders command_log content block", async () => {
    const { default: MessageBubble } =
      await import("../components/session/MessageBubble.vue");
    const message = makeTestMessage(
      "m3",
      "assistant",
      "command_log",
      "$ ls -la",
    );
    const wrapper = mount(MessageBubble, { props: { message } });
    expect(wrapper.exists()).toBe(true);
  });

  it("renders thinking content block", async () => {
    const { default: MessageBubble } =
      await import("../components/session/MessageBubble.vue");
    const message = makeTestMessage(
      "m4",
      "assistant",
      "thinking",
      "Let me think...",
    );
    const wrapper = mount(MessageBubble, { props: { message } });
    expect(wrapper.exists()).toBe(true);
  });
});
