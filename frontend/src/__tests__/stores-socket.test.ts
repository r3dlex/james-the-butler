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
  api: { setToken: vi.fn(), get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));

// Fully mock phoenix service with controllable callbacks
const mockOnOpen = vi.fn();
const mockOnClose = vi.fn();
const mockOnError = vi.fn();

const mockChannelLeave = vi.fn();
const mockChannelJoin = vi.fn(() => ({
  receive: vi.fn((_event: string, _cb: () => void) => ({ receive: vi.fn() })),
}));

const mockSocket = {
  onOpen: (cb: () => void) => mockOnOpen.mockImplementation(cb),
  onClose: (cb: () => void) => mockOnClose.mockImplementation(cb),
  onError: (cb: () => void) => mockOnError.mockImplementation(cb),
  channel: vi.fn((_topic: string, _params: unknown) => ({
    join: mockChannelJoin,
    leave: mockChannelLeave,
  })),
};

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(() => mockSocket),
}));

describe("useSocketStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("is importable and usable", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    expect(store).toBeDefined();
  });

  it("status starts as disconnected", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    expect(store.status).toBe("disconnected");
  });

  it("channels starts as empty Map", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    expect(store.channels.size).toBe(0);
  });

  it("connect sets status to connecting", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    store.connect();
    expect(store.status).toBe("connecting");
  });

  it("disconnect sets status to disconnected", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    store.connect();
    store.disconnect();
    expect(store.status).toBe("disconnected");
  });

  it("joinChannel returns a channel object", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    const channel = store.joinChannel("session:abc");
    expect(channel).toBeDefined();
  });

  it("joinChannel does not call socket.channel() twice for the same topic", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    const { getSocket } = await import("../services/phoenix");
    const sock = (getSocket as ReturnType<typeof vi.fn>)();
    const channelSpy = sock.channel as ReturnType<typeof vi.fn>;
    channelSpy.mockClear();
    store.joinChannel("session:same-topic");
    store.joinChannel("session:same-topic");
    // socket.channel() should only have been called once
    expect(channelSpy).toHaveBeenCalledTimes(1);
  });

  it("leaveChannel removes channel from the map", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    store.joinChannel("session:leave-me");
    store.leaveChannel("session:leave-me");
    expect(store.channels.has("session:leave-me")).toBe(false);
  });

  it("leaveChannel does nothing for unknown topic", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    expect(() => store.leaveChannel("nonexistent:topic")).not.toThrow();
  });

  it("disconnect clears all channels", async () => {
    const { useSocketStore } = await import("../stores/socket");
    const store = useSocketStore();
    store.joinChannel("session:a");
    store.joinChannel("session:b");
    store.disconnect();
    expect(store.channels.size).toBe(0);
  });
});
