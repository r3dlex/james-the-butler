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
    const msgs = [
      {
        id: "m1",
        role: "user" as const,
        content: [{ type: "text" as const, text: "Hello" }],
        insertedAt: new Date().toISOString(),
      },
    ];
    store.setMessages("sess-1", msgs);
    expect(store.getMessages("sess-1")).toHaveLength(1);
  });

  it("setMessages overwrites previous messages for the same session", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    const first = [
      {
        id: "m1",
        role: "user" as const,
        content: [{ type: "text" as const, text: "First" }],
        insertedAt: new Date().toISOString(),
      },
    ];
    const second = [
      {
        id: "m2",
        role: "assistant" as const,
        content: [{ type: "text" as const, text: "Second" }],
        insertedAt: new Date().toISOString(),
      },
    ];
    store.setMessages("sess-1", first);
    store.setMessages("sess-1", second);
    expect(store.getMessages("sess-1")).toHaveLength(1);
    expect(store.getMessages("sess-1")[0].id).toBe("m2");
  });

  it("appendMessage adds to existing messages", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    const msg = {
      id: "m3",
      role: "user" as const,
      content: [{ type: "text" as const, text: "Appended" }],
      insertedAt: new Date().toISOString(),
    };
    store.appendMessage("sess-2", msg);
    expect(store.getMessages("sess-2")).toHaveLength(1);
  });

  it("appendMessage accumulates messages", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    const make = (id: string) => ({
      id,
      role: "user" as const,
      content: [{ type: "text" as const, text: id }],
      insertedAt: new Date().toISOString(),
    });
    store.appendMessage("sess-3", make("a"));
    store.appendMessage("sess-3", make("b"));
    expect(store.getMessages("sess-3")).toHaveLength(2);
  });

  it("clearSession removes messages for a session", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    const msg = {
      id: "m4",
      role: "user" as const,
      content: [{ type: "text" as const, text: "Delete me" }],
      insertedAt: new Date().toISOString(),
    };
    store.setMessages("sess-4", [msg]);
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
      { type: "decomposing", description: "Analyzing...", taskId: undefined },
    ];
    store.setPlannerSteps(steps);
    expect(store.plannerSteps).toHaveLength(1);
    expect(store.plannerSteps[0].type).toBe("decomposing");
  });

  it("loading starts as false", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    expect(store.loading).toBe(false);
  });
});
