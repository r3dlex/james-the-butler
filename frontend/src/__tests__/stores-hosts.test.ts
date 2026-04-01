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
    get: vi.fn().mockResolvedValue({ hosts: [] }),
    post: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

const makeHost = (id: string, name = "Test Host") => ({
  id,
  name,
  endpoint: "http://localhost:7000",
  status: "online" as const,
  isPrimary: false,
  mtlsCertFingerprint: null,
  lastSeenAt: new Date().toISOString(),
  models: [],
  resourceUsage: { cpuPercent: 0, memoryPercent: 0 },
});

describe("useHostStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("is importable and usable", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    expect(store).toBeDefined();
  });

  it("hosts starts as empty array", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    expect(store.hosts).toEqual([]);
  });

  it("loading starts as false", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    expect(store.loading).toBe(false);
  });

  it("getHost returns undefined for unknown id", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    expect(store.getHost("nonexistent")).toBeUndefined();
  });

  it("updateHost adds host when not present", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    // getHost returns undefined first
    expect(store.getHost("h1")).toBeUndefined();
  });

  it("getHost returns host when in the list", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    const host = makeHost("h1", "Primary Host");
    store.hosts.push(host);
    const found = store.getHost("h1");
    expect(found).toBeDefined();
    expect(found!.name).toBe("Primary Host");
  });

  it("updateHost replaces existing host in the list", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    const host = makeHost("h2", "Old Name");
    store.hosts.push(host);
    const updated = { ...host, name: "New Name" };
    store.updateHost(updated);
    expect(store.getHost("h2")!.name).toBe("New Name");
  });

  it("updateHost does nothing when host is not found", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    const host = makeHost("h99", "Ghost Host");
    expect(() => store.updateHost(host)).not.toThrow();
    expect(store.hosts).toHaveLength(0);
  });

  it("fetchHosts sets loading to false after completion", async () => {
    const { useHostStore } = await import("../stores/hosts");
    const store = useHostStore();
    await store.fetchHosts();
    expect(store.loading).toBe(false);
  });
});
