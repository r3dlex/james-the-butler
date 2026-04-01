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

const makeModelConfig = (overrides = {}) => ({
  id: "mc1",
  hostId: "host-1",
  provider: "anthropic",
  model: "claude-sonnet-4-20250514",
  apiKey: "sk-test",
  isLocal: false,
  baseUrl: null,
  useOAuth: false,
  createdAt: "2024-01-01T00:00:00Z",
  ...overrides,
});

const makeMcpServer = (id: string, overrides = {}) => ({
  id,
  name: `Server ${id}`,
  transport: "stdio" as const,
  status: "connected" as const,
  isPreConfigured: false,
  params: {},
  ...overrides,
});

describe("useSettingsStore", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("loads model config from API", async () => {
    const { api } = await import("../services/api");
    const { useSettingsStore } = await import("../stores/settings");

    const config = makeModelConfig();
    vi.mocked(api.get).mockResolvedValueOnce({ modelConfig: config });

    const store = useSettingsStore();
    await store.fetchModelConfig();

    expect(api.get).toHaveBeenCalledWith("/api/settings/model_config");
    expect(store.modelConfig).toEqual(config);
    expect(store.error).toBeNull();
  });

  it("saves model config via API", async () => {
    const { api } = await import("../services/api");
    const { useSettingsStore } = await import("../stores/settings");

    const updated = makeModelConfig({ model: "claude-opus-4-20250514" });
    vi.mocked(api.put).mockResolvedValueOnce({ modelConfig: updated });

    const store = useSettingsStore();
    await store.saveModelConfig({ model: "claude-opus-4-20250514" });

    expect(api.put).toHaveBeenCalledWith("/api/settings/model_config", {
      model: "claude-opus-4-20250514",
    });
    expect(store.modelConfig).toEqual(updated);
    expect(store.error).toBeNull();
  });

  it("loads MCP servers from API", async () => {
    const { api } = await import("../services/api");
    const { useSettingsStore } = await import("../stores/settings");

    const servers = [makeMcpServer("s1"), makeMcpServer("s2")];
    vi.mocked(api.get).mockResolvedValueOnce({ mcpServers: servers });

    const store = useSettingsStore();
    await store.fetchMcpServers();

    expect(api.get).toHaveBeenCalledWith("/api/settings/mcp_servers");
    expect(store.mcpServers).toEqual(servers);
    expect(store.error).toBeNull();
  });

  it("adds MCP server via API", async () => {
    const { api } = await import("../services/api");
    const { useSettingsStore } = await import("../stores/settings");

    const newServer = makeMcpServer("s3");
    vi.mocked(api.post).mockResolvedValueOnce({ mcpServer: newServer });

    const store = useSettingsStore();
    await store.addMcpServer({
      name: "Server s3",
      transport: "stdio",
      isPreConfigured: false,
      params: {},
    });

    expect(api.post).toHaveBeenCalledWith(
      "/api/settings/mcp_servers",
      expect.objectContaining({ name: "Server s3" }),
    );
    expect(store.mcpServers).toHaveLength(1);
    expect(store.mcpServers[0].id).toBe("s3");
  });

  it("removes MCP server via API", async () => {
    const { api } = await import("../services/api");
    const { useSettingsStore } = await import("../stores/settings");

    // Seed two servers
    const s1 = makeMcpServer("s1");
    const s2 = makeMcpServer("s2");
    vi.mocked(api.get).mockResolvedValueOnce({ mcpServers: [s1, s2] });
    vi.mocked(api.delete).mockResolvedValueOnce(undefined);

    const store = useSettingsStore();
    await store.fetchMcpServers();
    await store.removeMcpServer("s1");

    expect(api.delete).toHaveBeenCalledWith("/api/settings/mcp_servers/s1");
    expect(store.mcpServers).toHaveLength(1);
    expect(store.mcpServers[0].id).toBe("s2");
  });
});
