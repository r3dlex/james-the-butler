// @vitest-environment happy-dom
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { createPinia, setActivePinia } from "pinia";

const localStorageData: Record<string, string> = {};
const localStorageMock = {
  getItem: (key: string) => localStorageData[key] ?? null,
  setItem: (key: string, val: string) => {
    localStorageData[key] = val;
  },
  removeItem: (key: string) => {
    delete localStorageData[key];
  },
  clear: () => {
    for (const k of Object.keys(localStorageData)) delete localStorageData[k];
  },
  get length() {
    return Object.keys(localStorageData).length;
  },
  key: (i: number) => Object.keys(localStorageData)[i] ?? null,
};
vi.stubGlobal("localStorage", localStorageMock);

vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn().mockResolvedValue({ session: { messageCount: 3 } }),
    post: vi.fn().mockResolvedValue({
      message: { id: "m1", role: "assistant", content: "Hi" },
    }),
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(() => ({
    onOpen: vi.fn(),
    onClose: vi.fn(),
    onError: vi.fn(),
    channel: vi.fn(() => ({
      join: vi.fn(() => ({ receive: vi.fn(() => ({ receive: vi.fn() })) })),
      leave: vi.fn(),
    })),
  })),
}));

describe("useMessageStore", () => {
  // Helper that produces a valid Message fixture for the current Message type.
  const makeMsg = (
    id: string,
    role: "user" | "assistant" = "user",
    text = id,
    sessionId = "sess-1",
  ) => ({
    id,
    sessionId,
    role,
    content: [{ type: "text" as const, text }],
    attachments: [],
    tokenCount: 0,
    createdAt: new Date().toISOString(),
  });

  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("is importable and usable", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    expect(store).toBeDefined();
  });

  it("getMessages returns empty array for unknown session", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    expect(store.getMessages("unknown-session")).toEqual([]);
  });

  it("setMessages stores messages for a session", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.setMessages("sess-1", [makeMsg("m1")]);
    expect(store.getMessages("sess-1")).toHaveLength(1);
  });

  it("setMessages overwrites previous messages for the same session", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.setMessages("sess-1", [makeMsg("m1")]);
    store.setMessages("sess-1", [makeMsg("m2", "assistant")]);
    expect(store.getMessages("sess-1")).toHaveLength(1);
    expect(store.getMessages("sess-1")[0].id).toBe("m2");
  });

  it("appendMessage adds to existing messages", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.appendMessage("sess-2", makeMsg("m3", "user", "Appended", "sess-2"));
    expect(store.getMessages("sess-2")).toHaveLength(1);
  });

  it("appendMessage accumulates messages", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.appendMessage("sess-3", makeMsg("a", "user", "a", "sess-3"));
    store.appendMessage("sess-3", makeMsg("b", "user", "b", "sess-3"));
    expect(store.getMessages("sess-3")).toHaveLength(2);
  });

  it("clearSession removes messages for a session", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.setMessages("sess-4", [makeMsg("m4", "user", "Delete me", "sess-4")]);
    store.clearSession("sess-4");
    expect(store.getMessages("sess-4")).toEqual([]);
  });

  it("startStreaming sets streamingSessionId and initialises blocks", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-5");
    expect(store.streamingSessionId).toBe("sess-5");
    expect(store.streamingContent).toBe("");
    expect(store.streamingBlocks).toHaveLength(1);
  });

  it("appendStreamChunk accumulates streaming content", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-6");
    store.appendStreamChunk("Hello");
    store.appendStreamChunk(" World");
    expect(store.streamingContent).toBe("Hello World");
    expect(store.streamingBlocks[0].text).toBe("Hello World");
  });

  it("stopStreaming clears streaming state", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-7");
    store.appendStreamChunk("chunk");
    store.stopStreaming();
    expect(store.streamingSessionId).toBeNull();
    expect(store.streamingContent).toBe("");
    expect(store.streamingBlocks).toHaveLength(0);
  });

  it("setStreamingState sets both sessionId and blocks", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    const blocks = [{ type: "text" as const, text: "streaming..." }];
    store.setStreamingState("sess-8", blocks);
    expect(store.streamingSessionId).toBe("sess-8");
    expect(store.streamingBlocks).toEqual(blocks);
  });

  it("setStreamingState with null clears sessionId", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.setStreamingState(null);
    expect(store.streamingSessionId).toBeNull();
  });

  it("setPlannerSteps stores planner steps", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    const steps = [
      {
        id: "step-1",
        description: "Analyzing...",
        riskLevel: "read_only" as const,
        targetHost: "primary",
        status: "pending" as const,
      },
    ];
    store.setPlannerSteps(steps);
    expect(store.plannerSteps).toHaveLength(1);
    expect(store.plannerSteps[0].description).toBe("Analyzing...");
  });

  it("loading starts as false", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    expect(store.loading).toBe(false);
  });
});
