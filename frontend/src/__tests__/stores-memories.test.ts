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
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
}));

const makeMemory = (id: string, content = "A test memory") => ({
  id,
  content,
  sourceSessionId: null,
  sourceSessionName: null,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
});

describe("useMemoryStore", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("memories starts as empty array", async () => {
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();
    expect(store.memories).toEqual([]);
  });

  it("loading starts as false", async () => {
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();
    expect(store.loading).toBe(false);
  });

  it("fetchMemories loads memories from API", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    const mockMemories = [
      makeMemory("m1", "User prefers Elixir"),
      makeMemory("m2", "Working on James project"),
    ];
    vi.mocked(api.get).mockResolvedValueOnce({ memories: mockMemories });

    await store.fetchMemories();

    expect(api.get).toHaveBeenCalledWith("/api/memories");
    expect(store.memories).toHaveLength(2);
    expect(store.memories[0].content).toBe("User prefers Elixir");
  });

  it("fetchMemories sets loading to false after completion", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    vi.mocked(api.get).mockResolvedValueOnce({ memories: [] });
    await store.fetchMemories();

    expect(store.loading).toBe(false);
  });

  it("fetchMemories handles API error gracefully", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    vi.mocked(api.get).mockRejectedValueOnce(new Error("Network error"));
    await store.fetchMemories();

    expect(store.memories).toEqual([]);
    expect(store.loading).toBe(false);
  });

  it("searchMemories calls API with encoded query parameter", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    const mockMemories = [makeMemory("m1", "User prefers Elixir")];
    vi.mocked(api.get).mockResolvedValueOnce({ memories: mockMemories });

    await store.searchMemories("Elixir");

    expect(api.get).toHaveBeenCalledWith("/api/memories?q=Elixir");
    expect(store.memories).toHaveLength(1);
    expect(store.memories[0].content).toBe("User prefers Elixir");
  });

  it("searchMemories encodes special characters in query", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    vi.mocked(api.get).mockResolvedValueOnce({ memories: [] });
    await store.searchMemories("search term with spaces");

    expect(api.get).toHaveBeenCalledWith(
      "/api/memories?q=search%20term%20with%20spaces",
    );
  });

  it("searchMemories replaces memories with search results", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    // Pre-populate the store
    store.memories.push(makeMemory("old1", "Old memory"));

    const searchResult = [makeMemory("m1", "Elixir memory")];
    vi.mocked(api.get).mockResolvedValueOnce({ memories: searchResult });

    await store.searchMemories("Elixir");

    expect(store.memories).toHaveLength(1);
    expect(store.memories[0].content).toBe("Elixir memory");
  });

  it("deleteMemory calls DELETE and removes from local state", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    const memory = makeMemory("del-1", "Memory to delete");
    store.memories.push(memory);
    vi.mocked(api.delete).mockResolvedValueOnce(undefined);

    await store.deleteMemory("del-1");

    expect(api.delete).toHaveBeenCalledWith("/api/memories/del-1");
    expect(store.memories.find((m) => m.id === "del-1")).toBeUndefined();
  });

  it("deleteMemory removes from local state even if API fails", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    const memory = makeMemory("del-2", "Another memory");
    store.memories.push(memory);
    vi.mocked(api.delete).mockRejectedValueOnce(new Error("API error"));

    await store.deleteMemory("del-2");

    expect(store.memories.find((m) => m.id === "del-2")).toBeUndefined();
  });

  it("updateMemory calls PUT and updates local state", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    const memory = makeMemory("upd-1", "Old content");
    store.memories.push(memory);

    const updated = { ...memory, content: "New content" };
    vi.mocked(api.put).mockResolvedValueOnce({ memory: updated });

    const result = await store.updateMemory("upd-1", { content: "New content" });

    expect(api.put).toHaveBeenCalledWith("/api/memories/upd-1", {
      content: "New content",
    });
    expect(result?.content).toBe("New content");
    expect(store.memories.find((m) => m.id === "upd-1")?.content).toBe(
      "New content",
    );
  });

  it("updateMemory returns null on API error", async () => {
    const { api } = await import("../services/api");
    const { useMemoryStore } = await import("../stores/memories");
    const store = useMemoryStore();

    vi.mocked(api.put).mockRejectedValueOnce(new Error("API error"));

    const result = await store.updateMemory("nonexistent", {
      content: "New content",
    });

    expect(result).toBeNull();
  });
});
