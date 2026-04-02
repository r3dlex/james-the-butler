// @vitest-environment happy-dom
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { createPinia, setActivePinia } from "pinia";

vi.mock("../services/api", () => ({
  api: { setToken: vi.fn(), get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));
vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
}));

// ---------------------------------------------------------------------------
// formatDate helper (mirrors SessionListPage logic — tested independently)
// ---------------------------------------------------------------------------

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "—";
  const now = new Date();
  const diff = now.getTime() - d.getTime();
  if (diff < 0) return "just now"; // future dates (clock skew)
  if (diff < 60_000) return "just now";
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return d.toLocaleDateString();
}

const NOW = new Date("2026-04-02T12:00:00Z").getTime();

describe("formatDate helper", () => {
  beforeEach(() => vi.setSystemTime(NOW));
  afterEach(() => vi.useRealTimers());

  it("returns '—' for null", () => {
    expect(formatDate(null)).toBe("—");
  });

  it("returns '—' for undefined", () => {
    expect(formatDate(undefined)).toBe("—");
  });

  it("returns '—' for empty string", () => {
    expect(formatDate("")).toBe("—");
  });

  it("returns '—' for 'Invalid Date' string", () => {
    expect(formatDate("not-a-date")).toBe("—");
  });

  it("returns 'just now' for dates within the last minute", () => {
    const recent = new Date(NOW - 30_000).toISOString();
    expect(formatDate(recent)).toBe("just now");
  });

  it("returns 'Xm ago' for dates within the last hour", () => {
    const fiveMinAgo = new Date(NOW - 5 * 60_000).toISOString();
    expect(formatDate(fiveMinAgo)).toBe("5m ago");
  });

  it("returns 'Xh ago' for dates within the last 24 hours", () => {
    const twoHoursAgo = new Date(NOW - 2 * 3_600_000).toISOString();
    expect(formatDate(twoHoursAgo)).toBe("2h ago");
  });

  it("returns a locale date string for dates older than 24 hours", () => {
    const old = new Date(NOW - 2 * 86_400_000).toISOString();
    const result = formatDate(old);
    expect(result).not.toBe("—");
    expect(result).not.toContain("ago");
  });
});

// ---------------------------------------------------------------------------
// sortedSessions — null-safe date comparison
// ---------------------------------------------------------------------------

describe("useSessionStore — sortedSessions null-safe sort", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(NOW);
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.clearAllMocks();
  });

  it("sorts sessions by updatedAt descending", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    const s1 = store.createLocalSession({ agentType: "chat", hostId: "h" });
    vi.advanceTimersByTime(1000);
    const s2 = store.createLocalSession({ agentType: "chat", hostId: "h" });

    // s2 was created later → should appear first
    expect(store.sortedSessions[0].id).toBe(s2.id);
    expect(store.sortedSessions[1].id).toBe(s1.id);
  });

  it("does not crash when updatedAt is undefined (treats as oldest)", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    const s = store.createLocalSession({ agentType: "chat", hostId: "h" });
    // Simulate a bad session coming from the backend with no date
    store.sessions.push({
      ...s,
      id: "bad-date",
      updatedAt: undefined as unknown as string,
      createdAt: undefined as unknown as string,
    });

    // Should not throw
    expect(() => store.sortedSessions).not.toThrow();
    // The well-dated session should sort above the undated one
    const ids = store.sortedSessions.map((x) => x.id);
    expect(ids.indexOf(s.id)).toBeLessThan(ids.indexOf("bad-date"));
  });

  it("falls back to createdAt when updatedAt is missing", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    const older = store.createLocalSession({ agentType: "chat", hostId: "h" });
    vi.advanceTimersByTime(2000);
    const newer = store.createLocalSession({ agentType: "chat", hostId: "h" });

    // Strip updatedAt — sort should still use createdAt
    store.sessions[0] = { ...older, updatedAt: "" };
    store.sessions[1] = { ...newer, updatedAt: "" };

    expect(store.sortedSessions[0].id).toBe(newer.id);
  });
});

// ---------------------------------------------------------------------------
// deleteSession
// ---------------------------------------------------------------------------

describe("useSessionStore — deleteSession", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("removes session from local list after DELETE API call", async () => {
    const { api } = await import("../services/api");
    const { useSessionStore } = await import("../stores/sessions");

    vi.mocked(api.delete).mockResolvedValueOnce(undefined);

    const store = useSessionStore();
    const s = store.createLocalSession({ agentType: "chat", hostId: "h" });
    expect(store.sessions).toHaveLength(1);

    await store.deleteSession(s.id);

    expect(api.delete).toHaveBeenCalledWith(`/api/sessions/${s.id}`);
    expect(store.sessions).toHaveLength(0);
  });

  it("still removes session from local list if API returns an error (offline mode)", async () => {
    const { api } = await import("../services/api");
    const { useSessionStore } = await import("../stores/sessions");

    vi.mocked(api.delete).mockRejectedValueOnce(new Error("network"));

    const store = useSessionStore();
    const s = store.createLocalSession({ agentType: "chat", hostId: "h" });

    await store.deleteSession(s.id);

    expect(store.sessions).toHaveLength(0);
  });

  it("clears activeSessionId when the active session is deleted", async () => {
    const { api } = await import("../services/api");
    const { useSessionStore } = await import("../stores/sessions");

    vi.mocked(api.delete).mockResolvedValueOnce(undefined);

    const store = useSessionStore();
    const s = store.createLocalSession({ agentType: "chat", hostId: "h" });
    store.setActive(s.id);
    expect(store.activeSessionId).toBe(s.id);

    await store.deleteSession(s.id);

    expect(store.activeSessionId).toBeNull();
  });
});
