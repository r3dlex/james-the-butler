// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { createPinia, setActivePinia } from "pinia";

// ---------------------------------------------------------------------------
// Module mocks — must be declared before any imports that touch these modules
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeProvider(
  id: string,
  status: "connected" | "failed" | "untested" = "connected",
  lastTestedAt: string | null = null,
) {
  return {
    id,
    providerType: "anthropic" as const,
    displayName: `Provider ${id}`,
    authMethod: "api_key" as const,
    status,
    baseUrl: null,
    apiKeyMasked: "sk-****",
    lastTestedAt,
    models: [],
  };
}

const NOW = new Date("2026-04-02T12:00:00Z").getTime();
const STALE_AT = new Date(NOW - 26 * 60 * 1000).toISOString(); // 26 min ago
const FRESH_AT = new Date(NOW - 10 * 60 * 1000).toISOString(); // 10 min ago

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useProviderHeartbeat", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(NOW);
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  it("tick() calls testConnection for stale connected providers", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useProviderHeartbeat } =
      await import("../composables/useProviderHeartbeat");

    const store = useProviderStore();
    // Seed store with a stale connected provider (no backend call needed)
    store.providers.push(makeProvider("p1", "connected", STALE_AT));

    vi.mocked(api.post).mockResolvedValue({
      status: "connected",
      latencyMs: 50,
    });

    const { tick } = useProviderHeartbeat();
    tick();

    // Wait a microtask for the async testConnection to be invoked
    await Promise.resolve();
    expect(vi.mocked(api.post)).toHaveBeenCalledWith("/api/providers/p1/test");
  });

  it("tick() does NOT call testConnection for fresh (recently-tested) providers", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useProviderHeartbeat } =
      await import("../composables/useProviderHeartbeat");

    const store = useProviderStore();
    store.providers.push(makeProvider("p1", "connected", FRESH_AT));

    const { tick } = useProviderHeartbeat();
    tick();

    await Promise.resolve();
    expect(vi.mocked(api.post)).not.toHaveBeenCalled();
  });

  it("tick() does NOT call testConnection for failed providers", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useProviderHeartbeat } =
      await import("../composables/useProviderHeartbeat");

    const store = useProviderStore();
    store.providers.push(makeProvider("p1", "failed", STALE_AT));

    const { tick } = useProviderHeartbeat();
    tick();

    await Promise.resolve();
    expect(vi.mocked(api.post)).not.toHaveBeenCalled();
  });

  it("tick() does NOT call testConnection for untested providers", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useProviderHeartbeat } =
      await import("../composables/useProviderHeartbeat");

    const store = useProviderStore();
    store.providers.push(makeProvider("p1", "untested", null));

    const { tick } = useProviderHeartbeat();
    tick();

    await Promise.resolve();
    expect(vi.mocked(api.post)).not.toHaveBeenCalled();
  });

  it("start() fires tick automatically every 2 minutes", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useProviderHeartbeat } =
      await import("../composables/useProviderHeartbeat");

    const store = useProviderStore();
    store.providers.push(makeProvider("p1", "connected", STALE_AT));
    vi.mocked(api.post).mockResolvedValue({
      status: "connected",
      latencyMs: 50,
    });

    const { start, stop } = useProviderHeartbeat();
    start();

    // Advance 2 minutes → first automatic tick
    vi.advanceTimersByTime(2 * 60 * 1000);
    await Promise.resolve();
    expect(vi.mocked(api.post)).toHaveBeenCalledTimes(1);

    // Advance another 2 minutes → second tick
    vi.advanceTimersByTime(2 * 60 * 1000);
    await Promise.resolve();
    expect(vi.mocked(api.post)).toHaveBeenCalledTimes(2);

    stop();
  });

  it("stop() cancels the interval so no more ticks fire", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useProviderHeartbeat } =
      await import("../composables/useProviderHeartbeat");

    const store = useProviderStore();
    store.providers.push(makeProvider("p1", "connected", STALE_AT));
    vi.mocked(api.post).mockResolvedValue({
      status: "connected",
      latencyMs: 50,
    });

    const { start, stop } = useProviderHeartbeat();
    start();
    stop();

    vi.advanceTimersByTime(10 * 60 * 1000); // 10 minutes with no ticks
    await Promise.resolve();
    expect(vi.mocked(api.post)).not.toHaveBeenCalled();
  });

  it("start() is idempotent — calling it twice does not create two timers", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useProviderHeartbeat } =
      await import("../composables/useProviderHeartbeat");

    const store = useProviderStore();
    store.providers.push(makeProvider("p1", "connected", STALE_AT));
    vi.mocked(api.post).mockResolvedValue({
      status: "connected",
      latencyMs: 50,
    });

    const { start, stop } = useProviderHeartbeat();
    start();
    start(); // second call should be a no-op

    vi.advanceTimersByTime(2 * 60 * 1000);
    await Promise.resolve();
    // Should only fire once, not twice
    expect(vi.mocked(api.post)).toHaveBeenCalledTimes(1);

    stop();
  });

  it("tick() treats a provider with no lastTestedAt as stale", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { useProviderHeartbeat } =
      await import("../composables/useProviderHeartbeat");

    const store = useProviderStore();
    // null lastTestedAt = never tested → stale
    store.providers.push(makeProvider("p1", "connected", null));
    vi.mocked(api.post).mockResolvedValue({
      status: "connected",
      latencyMs: 50,
    });

    const { tick } = useProviderHeartbeat();
    tick();

    await Promise.resolve();
    expect(vi.mocked(api.post)).toHaveBeenCalledWith("/api/providers/p1/test");
  });
});
