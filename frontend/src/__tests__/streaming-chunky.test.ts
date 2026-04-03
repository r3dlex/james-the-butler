// @vitest-environment happy-dom
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { createPinia, setActivePinia } from "pinia";

vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn().mockResolvedValue({ session: { messageCount: 0 } }),
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

describe("appendStreamChunk — newline normalisation", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  it("collapses more than 2 consecutive newlines to exactly 2", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-nl");

    store.appendStreamChunk("Hello\n\n\n\nWorld");
    // flush the batching timer
    vi.runAllTimers();

    expect(store.streamingContent).toBe("Hello\n\nWorld");
  });

  it("leaves exactly 2 consecutive newlines unchanged", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-nl2");

    store.appendStreamChunk("Hello\n\nWorld");
    vi.runAllTimers();

    expect(store.streamingContent).toBe("Hello\n\nWorld");
  });

  it("leaves single newlines unchanged", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-nl3");

    store.appendStreamChunk("Line1\nLine2");
    vi.runAllTimers();

    expect(store.streamingContent).toBe("Line1\nLine2");
  });

  it("collapses triple newlines split across multiple chunks", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-nl4");

    store.appendStreamChunk("Hello\n\n\n");
    store.appendStreamChunk("\nWorld");
    vi.runAllTimers();

    expect(store.streamingContent).toBe("Hello\n\nWorld");
  });
});

describe("appendStreamChunk — chunk batching", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  it("does not update streamingContent immediately when called rapidly", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-batch");

    // Call appendStreamChunk three times in a row without advancing timers
    store.appendStreamChunk("chunk1");
    store.appendStreamChunk("chunk2");
    store.appendStreamChunk("chunk3");

    // Before the flush timer fires, streamingContent must NOT reflect all chunks.
    // It may be empty or contain only the first chunk, but NOT the final concatenation.
    expect(store.streamingContent).not.toBe("chunk1chunk2chunk3");
  });

  it("flushes all batched chunks after the debounce interval", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-flush");

    store.appendStreamChunk("A");
    store.appendStreamChunk("B");
    store.appendStreamChunk("C");

    vi.runAllTimers();

    expect(store.streamingContent).toBe("ABC");
    expect(store.streamingBlocks[0].text).toBe("ABC");
  });

  it("streamingBlocks text matches streamingContent after flush", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-blocks");

    store.appendStreamChunk("Hello ");
    store.appendStreamChunk("World");
    vi.runAllTimers();

    expect(store.streamingBlocks[0].text).toBe(store.streamingContent);
  });

  it("stopStreaming flushes pending buffer immediately", async () => {
    const { useMessageStore } = await import("../stores/messages");
    const store = useMessageStore();
    store.startStreaming("sess-stop");

    store.appendStreamChunk("pending");
    // Do NOT advance timers — stopStreaming should flush inline
    store.stopStreaming();

    expect(store.streamingSessionId).toBeNull();
    expect(store.streamingContent).toBe("");
  });
});
