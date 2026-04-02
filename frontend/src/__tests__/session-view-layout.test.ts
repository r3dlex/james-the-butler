// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";

// Mock heavy dependencies
vi.mock("../services/api", () => ({
  api: { get: vi.fn(), post: vi.fn(), put: vi.fn(), delete: vi.fn() },
}));
vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
}));
vi.mock("vue-router", () => ({
  useRoute: () => ({ params: { id: "session-1" } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock("../stores/sessions", () => ({
  useSessionStore: () => ({
    fetchSession: vi.fn(),
    setActive: vi.fn(),
    sessions: [],
    currentSession: null,
    update: vi.fn(),
    updateSession: vi.fn(),
    renameSession: vi.fn(),
  }),
}));
vi.mock("../stores/messages", () => ({
  useMessageStore: () => ({
    messages: [],
    getMessages: vi.fn(() => []),
    fetchMessages: vi.fn(),
    addMessage: vi.fn(),
    streamingSessionId: null,
    streamingContent: "",
  }),
}));
vi.mock("../stores/tasks", () => ({
  useTaskStore: () => ({
    tasks: [],
    fetchTasks: vi.fn(),
    getTasksForSession: vi.fn(() => []),
  }),
}));
vi.mock("../stores/socket", () => ({
  useSocketStore: () => ({
    joinSession: vi.fn(),
    leaveSession: vi.fn(),
    joinChannel: vi.fn(() => ({
      on: vi.fn(),
      leave: vi.fn(),
      push: vi.fn(() => ({ receive: vi.fn() })),
    })),
    leaveChannel: vi.fn(),
    send: vi.fn(),
    socket: null,
  }),
}));
vi.mock("../stores/tokens", () => ({
  useTokenStore: () => ({ getUsage: vi.fn(() => null) }),
}));
vi.mock("../components/session/SessionActivityPanel.vue", () => ({
  default: { template: '<div data-testid="activity-panel" />' },
}));
vi.mock("../components/session/ChatMessageStream.vue", () => ({
  default: { template: '<div data-testid="chat-messages" />' },
}));
vi.mock("../components/session/ChatInput.vue", () => ({
  default: { template: '<div data-testid="chat-input" />' },
}));

// Stub localStorage
const localStorageData: Record<string, string> = {};
vi.stubGlobal("localStorage", {
  getItem: (k: string) => localStorageData[k] ?? null,
  setItem: (k: string, v: string) => {
    localStorageData[k] = v;
  },
  removeItem: (k: string) => {
    delete localStorageData[k];
  },
  clear: () => {
    for (const k of Object.keys(localStorageData)) delete localStorageData[k];
  },
  get length() {
    return Object.keys(localStorageData).length;
  },
  key: (i: number) => Object.keys(localStorageData)[i] ?? null,
});

describe("SessionView layout", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("chat input container does not have overflow hidden or auto", async () => {
    const { default: SessionView } = await import("../pages/SessionView.vue");
    const wrapper = mount(SessionView, { attachTo: document.body });

    // The resizable chat input container has BOTH a height and overflow style.
    // The resize handle has only height (4px), so we filter by overflow presence.
    const allDivs = wrapper.findAll("div");
    const resizableDiv = allDivs.find((div) => {
      const s = div.attributes("style") ?? "";
      return s.includes("height") && s.includes("overflow");
    });
    expect(resizableDiv).toBeDefined();

    const style = resizableDiv!.attributes("style") ?? "";
    expect(style).not.toMatch(/overflow\s*:\s*auto/);
    expect(style).not.toMatch(/overflow\s*:\s*hidden/);

    wrapper.unmount();
  });

  it("chat input default height is at least 300px", async () => {
    const { default: SessionView } = await import("../pages/SessionView.vue");
    const wrapper = mount(SessionView, { attachTo: document.body });

    // The resizable chat input container has BOTH a height and overflow style.
    const allDivs = wrapper.findAll("div");
    const resizableDiv = allDivs.find((div) => {
      const s = div.attributes("style") ?? "";
      return s.includes("height") && s.includes("overflow");
    });
    expect(resizableDiv).toBeDefined();

    const style = resizableDiv!.attributes("style") ?? "";
    const match = style.match(/height\s*:\s*(\d+(?:\.\d+)?)px/);
    expect(match).not.toBeNull();
    const height = parseFloat(match![1]);
    expect(height).toBeGreaterThanOrEqual(300);

    wrapper.unmount();
  });

  it("ChatInput is inside the resizable container (the div with dynamic height binding)", async () => {
    const { default: SessionView } = await import("../pages/SessionView.vue");
    const wrapper = mount(SessionView, { attachTo: document.body });

    // The resizable div has an inline height style
    const html = wrapper.html();

    // Find the position of the resizable container in the HTML
    const resizableStart = html.indexOf('style="height:');
    expect(resizableStart).toBeGreaterThan(-1);

    // Find the position of the chat-input element
    const chatInputPos = html.indexOf('data-testid="chat-input"');
    expect(chatInputPos).toBeGreaterThan(-1);

    // ChatInput must appear INSIDE the resizable div
    // i.e., after the opening tag and before its closing div
    // We check that chat-input appears after the resizable div starts
    expect(chatInputPos).toBeGreaterThan(resizableStart);

    // And that the mode selector (workspace bar) appears AFTER the chat input
    // which means it's outside the resizable container
    const modeSelectorPos = html.indexOf("<select");
    expect(modeSelectorPos).toBeGreaterThan(chatInputPos);

    wrapper.unmount();
  });

  it("workspace bar is OUTSIDE the resizable container (sibling after it, not inside)", async () => {
    const { default: SessionView } = await import("../pages/SessionView.vue");
    const wrapper = mount(SessionView, { attachTo: document.body });

    // The resizable div has an inline height style — find it
    const allDivs = wrapper.findAll("div");
    const resizableDiv = allDivs.find(
      (div) =>
        div.attributes("style") !== undefined &&
        div.attributes("style")!.includes("height"),
    );
    expect(resizableDiv).toBeDefined();

    // The workspace bar (containing the mode <select>) should NOT be inside the resizable div
    const selectInsideResizable = resizableDiv!.find("select");
    expect(selectInsideResizable.exists()).toBe(false);

    wrapper.unmount();
  });

  it("workspace bar has shrink-0 class and is not dynamically sized", async () => {
    const { default: SessionView } = await import("../pages/SessionView.vue");
    const wrapper = mount(SessionView, { attachTo: document.body });

    // Find the div that contains the mode <select>
    // This div is the workspace bar — it should have shrink-0 and no inline height style
    const html = wrapper.html();
    const selectPos = html.indexOf("<select");
    expect(selectPos).toBeGreaterThan(-1);

    // Walk backwards from the select to find its containing div with shrink-0
    const snippet = html.substring(0, selectPos);
    // The workspace bar outer div should have shrink-0
    expect(snippet).toMatch(/shrink-0[^>]*>/);

    // The workspace bar should NOT have a dynamic height style
    // Find the last div tag before the select
    const lastDivBeforeSelect = snippet.lastIndexOf("<div");
    const divTag = html.substring(lastDivBeforeSelect, selectPos);
    expect(divTag).not.toMatch(/style="[^"]*height/);

    wrapper.unmount();
  });
});
