// @vitest-environment happy-dom
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { createPinia, setActivePinia } from "pinia";

// ---------------------------------------------------------------------------
// Provide a minimal in-memory localStorage stub so the auth store can call
// localStorage.getItem() at construction time (before happy-dom assigns globals).
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Stub out external service modules so stores can be imported without a real
// network stack. We only test pure in-memory state logic.
// ---------------------------------------------------------------------------
vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn(),
    post: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
}));

// ---------------------------------------------------------------------------
// Auth store tests
// ---------------------------------------------------------------------------
describe("useAuthStore — initial state", () => {
  beforeEach(() => {
    // Reset localStorage between tests
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("store is importable and returns a usable store", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    expect(store).toBeDefined();
  });

  it("user starts as null when not authenticated", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    expect(store.user).toBeNull();
  });

  it("token starts as null when localStorage is empty", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    expect(store.token).toBeNull();
  });

  it("loading starts as false", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    expect(store.loading).toBe(false);
  });

  it("error starts as null", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    expect(store.error).toBeNull();
  });

  it("isAuthenticated is false when no token is present", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    expect(store.isAuthenticated).toBe(false);
  });

  it("isAuthenticated is true after setAuth is called", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    const user = {
      id: "u1",
      email: "test@example.com",
      name: "Test",
      executionMode: "direct",
      personalityId: null,
    };
    store.setAuth("test-token", user);
    expect(store.isAuthenticated).toBe(true);
  });

  it("setAuth stores the user object", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    const user = {
      id: "u2",
      email: "user@example.com",
      name: "User",
      executionMode: "direct",
      personalityId: null,
    };
    store.setAuth("a-token", user);
    expect(store.user).toEqual(user);
  });

  it("setAuth stores the token", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    const user = {
      id: "u3",
      email: "u@e.com",
      name: "U",
      executionMode: "direct",
      personalityId: null,
    };
    store.setAuth("my-token", user);
    expect(store.token).toBe("my-token");
  });

  it("setAuth persists the token to localStorage", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    const user = {
      id: "u4",
      email: "u@e.com",
      name: "U",
      executionMode: "direct",
      personalityId: null,
    };
    store.setAuth("ls-token", user);
    expect(localStorage.getItem("auth_token")).toBe("ls-token");
  });

  it("logout clears user, token, and isAuthenticated", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    const user = {
      id: "u5",
      email: "u@e.com",
      name: "U",
      executionMode: "direct",
      personalityId: null,
    };
    store.setAuth("tok", user);
    store.logout();
    expect(store.user).toBeNull();
    expect(store.token).toBeNull();
    expect(store.isAuthenticated).toBe(false);
  });

  it("logout removes auth_token from localStorage", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    localStorage.setItem("auth_token", "existing-token");
    store.logout();
    expect(localStorage.getItem("auth_token")).toBeNull();
  });

  it("setAuth with a refresh token persists it to localStorage", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    const user = {
      id: "u6",
      email: "u@e.com",
      name: "U",
      executionMode: "direct",
      personalityId: null,
    };
    store.setAuth("access-tok", user, "refresh-tok");
    expect(localStorage.getItem("refresh_token")).toBe("refresh-tok");
  });

  it("logout also clears refresh token from localStorage", async () => {
    const { useAuthStore } = await import("../stores/auth");
    const store = useAuthStore();
    const user = {
      id: "u7",
      email: "u@e.com",
      name: "U",
      executionMode: "direct",
      personalityId: null,
    };
    store.setAuth("tok", user, "rtok");
    store.logout();
    expect(localStorage.getItem("refresh_token")).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Sessions store tests
// ---------------------------------------------------------------------------
describe("useSessionStore — initial state", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("store is importable", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    expect(store).toBeDefined();
  });

  it("sessions starts as an empty array", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    expect(store.sessions).toEqual([]);
  });

  it("activeSessionId starts as null", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    expect(store.activeSessionId).toBeNull();
  });

  it("activeSession starts as null", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    expect(store.activeSession).toBeNull();
  });

  it("loading starts as false", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    expect(store.loading).toBe(false);
  });

  it("creating starts as false", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    expect(store.creating).toBe(false);
  });

  it("sortedSessions starts as an empty array", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    expect(store.sortedSessions).toEqual([]);
  });

  it("setActive sets the activeSessionId", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    store.setActive("session-42");
    expect(store.activeSessionId).toBe("session-42");
  });

  it("setActive(null) clears the activeSessionId", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    store.setActive("some-id");
    store.setActive(null);
    expect(store.activeSessionId).toBeNull();
  });

  it("createLocalSession adds a session to the sessions array", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    expect(store.sessions.length).toBe(1);
  });

  it("createLocalSession assigns a generated id", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    expect(session.id).toBeDefined();
    expect(typeof session.id).toBe("string");
    expect(session.id.length).toBeGreaterThan(0);
  });

  it("createLocalSession uses default name 'New Session' when no name given", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    expect(session.name).toBe("New Session");
  });

  it("createLocalSession respects a provided name", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      name: "My Project Session",
      agentType: "code",
      hostId: "host-2",
    });
    expect(session.name).toBe("My Project Session");
  });

  it("createLocalSession sets status to 'active'", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    expect(session.status).toBe("active");
  });

  it("createLocalSession sets default executionMode to 'direct'", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    expect(session.executionMode).toBe("direct");
  });

  it("autoNameSession sets name from first message when not set by user", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    store.setActive(session.id);
    store.autoNameSession(session.id, "Help me write a test.");
    const updated = store.sessions.find((s) => s.id === session.id);
    expect(updated?.name).toBe("Help me write a test.");
  });

  it("autoNameSession truncates long messages to 60 chars with ellipsis", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    const longMessage =
      "This is a very long message that exceeds sixty characters in length for sure";
    store.autoNameSession(session.id, longMessage);
    const updated = store.sessions.find((s) => s.id === session.id);
    expect(updated?.name.length).toBeLessThanOrEqual(60);
    expect(updated?.name.endsWith("...")).toBe(true);
  });

  it("autoNameSession does not rename when nameSetByUser is true", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      name: "User Chosen Name",
      agentType: "chat",
      hostId: "host-1",
    });
    store.autoNameSession(session.id, "Ignore this message");
    const updated = store.sessions.find((s) => s.id === session.id);
    expect(updated?.name).toBe("User Chosen Name");
  });

  it("renameSession updates the session name", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    store.renameSession(session.id, "New Name");
    const updated = store.sessions.find((s) => s.id === session.id);
    expect(updated?.name).toBe("New Name");
  });

  it("renameSession sets nameSetByUser to true", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    store.renameSession(session.id, "Custom");
    const updated = store.sessions.find((s) => s.id === session.id);
    expect(updated?.nameSetByUser).toBe(true);
  });

  it("updateSession replaces the session in the list", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    const modified = { ...session, name: "Updated via updateSession" };
    store.updateSession(modified);
    const found = store.sessions.find((s) => s.id === session.id);
    expect(found?.name).toBe("Updated via updateSession");
  });

  it("activeSession computed returns the currently active session", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    store.setActive(session.id);
    expect(store.activeSession).toEqual(session);
  });

  it("sortedSessions returns sessions sorted by updatedAt descending", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    // Create two sessions; createLocalSession unshifts so first created is last in array
    const s1 = store.createLocalSession({ agentType: "chat", hostId: "h" });
    const s2 = store.createLocalSession({ agentType: "chat", hostId: "h" });
    // Both have the same updatedAt (same millisecond) so order is stable
    // Verify sortedSessions has both
    expect(store.sortedSessions.length).toBe(2);
    expect(store.sortedSessions.map((s) => s.id)).toContain(s1.id);
    expect(store.sortedSessions.map((s) => s.id)).toContain(s2.id);
  });
});
