// @vitest-environment happy-dom
/**
 * TDD tests for Issue 2: Sessions appear in sidebar after creation.
 *
 * The sidebar (SidebarSessionsSection) reads from sessionStore.sessions.
 * After createSession() or createLocalSession(), the new session must
 * be present in sortedSessions so the sidebar renders it.
 */
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
    delete: vi.fn(),
    put: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
}));

describe("Session sidebar visibility after creation", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("after createSession() API success, sortedSessions includes the new session", async () => {
    const { api } = await import("../services/api");
    const { useSessionStore } = await import("../stores/sessions");
    const { useProviderStore } = await import("../stores/providers");

    const providerStore = useProviderStore();
    // Add a fake provider so canCreateSession is true
    providerStore.providers.push({
      id: "p1",
      providerId: "anthropic",
      displayName: "Anthropic",
      status: "connected",
      authMethod: "api_key",
      userId: "u1",
    } as never);

    const store = useSessionStore();

    const newSession = {
      id: "server-session-1",
      name: "Fresh Session",
      nameSetByUser: false,
      agentType: "chat" as const,
      hostId: "h1",
      projectId: null,
      status: "active" as const,
      executionMode: "direct" as const,
      personalityId: null,
      workingDirectories: [],
      mcpServers: [],
      keepIntermediates: false,
      tokenCount: 0,
      tokenCost: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    vi.mocked(api.post).mockResolvedValueOnce({ session: newSession });

    const result = await store.createSession({
      agentType: "chat",
      hostId: "h1",
    });

    expect(result).not.toBeNull();
    expect(result?.id).toBe("server-session-1");

    // The session should be in sortedSessions (which the sidebar reads)
    const ids = store.sortedSessions.map((s) => s.id);
    expect(ids).toContain("server-session-1");
  });

  it("after createSession() API failure, local fallback session appears in sortedSessions", async () => {
    const { api } = await import("../services/api");
    const { useSessionStore } = await import("../stores/sessions");
    const { useProviderStore } = await import("../stores/providers");

    const providerStore = useProviderStore();
    providerStore.providers.push({
      id: "p1",
      providerId: "anthropic",
      displayName: "Anthropic",
      status: "connected",
      authMethod: "api_key",
      userId: "u1",
    } as never);

    const store = useSessionStore();

    vi.mocked(api.post).mockRejectedValueOnce(new Error("Network error"));

    const result = await store.createSession({
      agentType: "chat",
      hostId: "h1",
      name: "Offline Session",
    });

    // Should fall back to a local session
    expect(result).not.toBeNull();
    expect(result?.name).toBe("Offline Session");

    // Must appear in sortedSessions for the sidebar to show it
    const ids = store.sortedSessions.map((s) => s.id);
    expect(ids).toContain(result!.id);
  });

  it("createLocalSession immediately adds session to sortedSessions", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    const session = store.createLocalSession({
      agentType: "code",
      hostId: "h1",
      name: "Local Dev Session",
    });

    const ids = store.sortedSessions.map((s) => s.id);
    expect(ids).toContain(session.id);
  });
});
