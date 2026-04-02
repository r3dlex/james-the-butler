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
    get: vi.fn().mockResolvedValue({ sessions: [], projects: [] }),
    post: vi.fn().mockResolvedValue({
      message: {
        id: "server-m1",
        role: "user",
        sessionId: "sess-1",
        content: [{ type: "text", text: "Hello" }],
        attachments: [],
        tokenCount: 0,
        createdAt: new Date().toISOString(),
      },
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

describe("chat deduplication", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("sendMessage does NOT push the REST response to the message list", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();

    // Pre-populate with an optimistic temp message
    store.appendMessage("sess-1", makeMsg("temp-123", "user", "Hello"));

    const result = await store.sendMessage("sess-1", "Hello");

    // The REST response should be returned
    expect(result).toBeDefined();
    expect(result?.id).toBe("server-m1");

    // But only the ONE temp message should be in the list (no duplicate)
    const msgs = store.getMessages("sess-1");
    expect(msgs).toHaveLength(1);
    expect(msgs[0].id).toBe("temp-123");
  });

  it("replaceOrAppendMessage replaces temp message with same role", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();

    const tempMsg = makeMsg("temp-456", "user", "Hello world");
    store.appendMessage("sess-1", tempMsg);

    const serverMsg = makeMsg("server-real", "user", "Hello world");
    store.replaceOrAppendMessage("sess-1", serverMsg);

    const msgs = store.getMessages("sess-1");
    expect(msgs).toHaveLength(1);
    expect(msgs[0].id).toBe("server-real");
  });

  it("replaceOrAppendMessage appends when no temp message exists with same role", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();

    const existing = makeMsg("existing-1", "assistant", "I am the assistant");
    store.appendMessage("sess-1", existing);

    const newMsg = makeMsg("server-user", "user", "New question");
    store.replaceOrAppendMessage("sess-1", newMsg);

    const msgs = store.getMessages("sess-1");
    expect(msgs).toHaveLength(2);
    expect(msgs[1].id).toBe("server-user");
  });

  it("replaceOrAppendMessage only replaces temp- prefixed messages", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();

    // A real (non-temp) user message
    const realMsg = makeMsg("real-msg-1", "user", "Hello world");
    store.appendMessage("sess-1", realMsg);

    const serverMsg = makeMsg("server-new", "user", "Hello world");
    store.replaceOrAppendMessage("sess-1", serverMsg);

    const msgs = store.getMessages("sess-1");
    // real-msg-1 should not be replaced — server-new appended
    expect(msgs).toHaveLength(2);
    expect(msgs[0].id).toBe("real-msg-1");
    expect(msgs[1].id).toBe("server-new");
  });

  it("replaceOrAppendMessage is exported from the store", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    expect(typeof store.replaceOrAppendMessage).toBe("function");
  });
});
