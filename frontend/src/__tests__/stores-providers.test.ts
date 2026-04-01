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

const makeProvider = (id: string, overrides = {}) => ({
  id,
  providerType: "anthropic" as const,
  displayName: `Provider ${id}`,
  authMethod: "api_key" as const,
  status: "untested" as const,
  baseUrl: null,
  apiKeyMasked: "sk-****",
  lastTestedAt: null,
  models: [],
  ...overrides,
});

describe("useProviderStore", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("fetchProviders() populates providers ref from API", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const providerList = [makeProvider("p1"), makeProvider("p2")];
    vi.mocked(api.get).mockResolvedValueOnce({ providers: providerList });

    const store = useProviderStore();
    await store.fetchProviders();

    expect(api.get).toHaveBeenCalledWith("/api/providers");
    expect(store.providers).toEqual(providerList);
    expect(store.error).toBeNull();
  });

  it("addProvider(data) calls POST and appends to list", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const newProvider = makeProvider("p3");
    vi.mocked(api.post).mockResolvedValueOnce({ provider: newProvider });

    const store = useProviderStore();
    await store.addProvider({
      providerType: "anthropic",
      displayName: "Provider p3",
      authMethod: "api_key",
      baseUrl: null,
    });

    expect(api.post).toHaveBeenCalledWith(
      "/api/providers",
      expect.objectContaining({ displayName: "Provider p3" }),
    );
    expect(store.providers).toHaveLength(1);
    expect(store.providers[0].id).toBe("p3");
  });

  it("updateProvider(id, data) calls PUT and updates in place", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const existing = makeProvider("p1");
    const updated = { ...existing, displayName: "Updated Provider" };
    vi.mocked(api.get).mockResolvedValueOnce({ providers: [existing] });
    vi.mocked(api.put).mockResolvedValueOnce({ provider: updated });

    const store = useProviderStore();
    await store.fetchProviders();
    await store.updateProvider("p1", { displayName: "Updated Provider" });

    expect(api.put).toHaveBeenCalledWith("/api/providers/p1", {
      displayName: "Updated Provider",
    });
    expect(store.providers[0].displayName).toBe("Updated Provider");
  });

  it("removeProvider(id) calls DELETE and removes from list", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const p1 = makeProvider("p1");
    const p2 = makeProvider("p2");
    vi.mocked(api.get).mockResolvedValueOnce({ providers: [p1, p2] });
    vi.mocked(api.delete).mockResolvedValueOnce(undefined);

    const store = useProviderStore();
    await store.fetchProviders();
    await store.removeProvider("p1");

    expect(api.delete).toHaveBeenCalledWith("/api/providers/p1");
    expect(store.providers).toHaveLength(1);
    expect(store.providers[0].id).toBe("p2");
  });

  it("testConnection(id) calls POST /providers/:id/test and updates status from real API response shape", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const existing = makeProvider("p1");
    vi.mocked(api.get).mockResolvedValueOnce({ providers: [existing] });
    // Real API response: {status: "connected", latencyMs: 1618} (no provider wrapper)
    vi.mocked(api.post).mockResolvedValueOnce({
      status: "connected",
      latencyMs: 1618,
    });

    const store = useProviderStore();
    await store.fetchProviders();
    await store.testConnection("p1");

    expect(api.post).toHaveBeenCalledWith("/api/providers/p1/test");
    expect(store.providers[0].status).toBe("connected");
    expect(store.loading).toBe(false);
  });

  it("fetchModels(id) calls GET /providers/:id/models and updates models array", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const existing = makeProvider("p1");
    vi.mocked(api.get)
      .mockResolvedValueOnce({ providers: [existing] })
      .mockResolvedValueOnce({ models: ["claude-opus-4", "claude-sonnet-4"] });

    const store = useProviderStore();
    await store.fetchProviders();
    await store.fetchModels("p1");

    expect(api.get).toHaveBeenCalledWith("/api/providers/p1/models");
    expect(store.providers[0].models).toEqual([
      "claude-opus-4",
      "claude-sonnet-4",
    ]);
  });

  it("hasVerifiedProvider computed returns false when no providers connected", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const providerList = [
      makeProvider("p1", { status: "untested" }),
      makeProvider("p2", { status: "failed" }),
    ];
    vi.mocked(api.get).mockResolvedValueOnce({ providers: providerList });

    const store = useProviderStore();
    await store.fetchProviders();

    expect(store.hasVerifiedProvider).toBe(false);
  });

  it("hasVerifiedProvider returns true when at least one provider has status connected", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const providerList = [
      makeProvider("p1", { status: "untested" }),
      makeProvider("p2", { status: "connected" }),
    ];
    vi.mocked(api.get).mockResolvedValueOnce({ providers: providerList });

    const store = useProviderStore();
    await store.fetchProviders();

    expect(store.hasVerifiedProvider).toBe(true);
  });

  it("fetchProviders() defaults models to [] when API response omits models field", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    // API returns providers without 'models' field (real API behavior)
    const apiResponse = {
      id: "p1",
      providerType: "minimax",
      displayName: "MiniMax",
      authMethod: "api_key",
      status: "untested",
      baseUrl: "https://api.minimax.io/anthropic",
      apiKeyMasked: "sk-...1234",
      lastTestedAt: null,
      // no models field!
    };
    vi.mocked(api.get).mockResolvedValueOnce({ providers: [apiResponse] });

    const store = useProviderStore();
    await store.fetchProviders();

    expect(store.providers[0].models).toEqual([]);
  });

  it("addProvider() defaults models to [] when API response omits models field", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    // API returns created provider without 'models' field
    const apiResponse = {
      id: "p1",
      providerType: "minimax",
      displayName: "MiniMax",
      authMethod: "api_key",
      status: "untested",
      baseUrl: "https://api.minimax.io/anthropic",
      apiKey: "sk-...1234",
      lastTestedAt: null,
      // no models field!
    };
    vi.mocked(api.post).mockResolvedValueOnce({ provider: apiResponse });

    const store = useProviderStore();
    await store.addProvider({
      providerType: "minimax",
      displayName: "MiniMax",
      authMethod: "api_key",
      baseUrl: "https://api.minimax.io/anthropic",
    });

    expect(store.providers).toHaveLength(1);
    expect(store.providers[0].models).toEqual([]);
    expect(store.providers[0].displayName).toBe("MiniMax");
  });

  it("addProvider() auto-fetches models after successful creation", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    const newProvider = {
      id: "p1",
      providerType: "minimax",
      displayName: "MiniMax",
      authMethod: "api_key",
      status: "untested",
      baseUrl: "https://api.minimax.io/anthropic",
      apiKey: "sk-...1234",
      lastTestedAt: null,
    };
    vi.mocked(api.post).mockResolvedValueOnce({ provider: newProvider });
    vi.mocked(api.get).mockResolvedValueOnce({
      models: ["MiniMax-M2.7", "MiniMax-M2.5"],
    });

    const store = useProviderStore();
    await store.addProvider({
      providerType: "minimax",
      displayName: "MiniMax",
      authMethod: "api_key",
      baseUrl: "https://api.minimax.io/anthropic",
    });

    // Should have auto-fetched models
    expect(api.get).toHaveBeenCalledWith("/api/providers/p1/models");
    expect(store.providers[0].models).toEqual(["MiniMax-M2.7", "MiniMax-M2.5"]);
  });

  it("error handling sets error ref", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");

    vi.mocked(api.get).mockRejectedValueOnce({ error: "Network error" });

    const store = useProviderStore();
    await store.fetchProviders();

    expect(store.error).toBe("Network error");
    expect(store.providers).toHaveLength(0);
  });
});
