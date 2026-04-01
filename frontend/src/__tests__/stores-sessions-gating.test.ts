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

describe("useSessionStore — provider gating", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("canCreateSession returns false when hasVerifiedProvider is false", async () => {
    const { useProviderStore } = await import("../stores/providers");
    const { useSessionStore } = await import("../stores/sessions");

    const providerStore = useProviderStore();
    providerStore.providers.push(makeProvider("p1", { status: "untested" }));

    const store = useSessionStore();
    expect(store.canCreateSession).toBe(false);
  });

  it("canCreateSession returns true when hasVerifiedProvider is true", async () => {
    const { useProviderStore } = await import("../stores/providers");
    const { useSessionStore } = await import("../stores/sessions");

    const providerStore = useProviderStore();
    providerStore.providers.push(makeProvider("p1", { status: "connected" }));

    const store = useSessionStore();
    expect(store.canCreateSession).toBe(true);
  });

  it("createSession() returns null and sets error when no verified provider", async () => {
    const { useProviderStore } = await import("../stores/providers");
    const { useSessionStore } = await import("../stores/sessions");

    const providerStore = useProviderStore();
    providerStore.providers.push(makeProvider("p1", { status: "untested" }));

    const store = useSessionStore();
    const result = await store.createSession({
      agentType: "chat",
      hostId: "host-1",
    });

    expect(result).toBeNull();
    expect(store.createError).toBeTruthy();
  });

  it("createSession() proceeds normally when provider is verified", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useSessionStore } = await import("../stores/sessions");

    const providerStore = useProviderStore();
    providerStore.providers.push(makeProvider("p1", { status: "connected" }));

    const session = {
      id: "sess-1",
      name: "New Session",
      nameSetByUser: false,
      agentType: "chat",
      hostId: "host-1",
      projectId: null,
      status: "active",
      executionMode: "direct",
      personalityId: null,
      workingDirectories: [],
      mcpServers: [],
      keepIntermediates: false,
      tokenCount: 0,
      tokenCost: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    vi.mocked(api.post).mockResolvedValueOnce({ session });

    const store = useSessionStore();
    const result = await store.createSession({
      agentType: "chat",
      hostId: "host-1",
    });

    expect(result).not.toBeNull();
    expect(result?.id).toBe("sess-1");
    expect(store.createError).toBeNull();
  });

  it("error message directs user to Settings > Models", async () => {
    const { useProviderStore } = await import("../stores/providers");
    const { useSessionStore } = await import("../stores/sessions");

    const providerStore = useProviderStore();
    // no providers at all
    providerStore.providers.splice(0);

    const store = useSessionStore();
    await store.createSession({ agentType: "chat", hostId: "host-1" });

    expect(store.createError).toContain("Settings");
    expect(store.createError).toContain("Models");
  });
});
