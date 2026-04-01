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
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
}));

describe("useSessionStore — session lifecycle actions", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("suspendSession calls POST /api/sessions/:id/suspend and updates local state", async () => {
    const { api } = await import("../services/api");
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    const suspended = { ...session, status: "suspended" };
    vi.mocked(api.post).mockResolvedValueOnce({ session: suspended });

    await store.suspendSession(session.id);

    expect(api.post).toHaveBeenCalledWith(
      `/api/sessions/${session.id}/suspend`,
    );
    const found = store.sessions.find((s) => s.id === session.id);
    expect(found?.status).toBe("suspended");
  });

  it("resumeSession calls POST /api/sessions/:id/resume and updates local state", async () => {
    const { api } = await import("../services/api");
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    // Manually set status to suspended first
    const idx = store.sessions.findIndex((s) => s.id === session.id);
    store.sessions[idx] = { ...session, status: "suspended" };

    const resumed = { ...session, status: "active" };
    vi.mocked(api.post).mockResolvedValueOnce({ session: resumed });

    await store.resumeSession(session.id);

    expect(api.post).toHaveBeenCalledWith(`/api/sessions/${session.id}/resume`);
    const found = store.sessions.find((s) => s.id === session.id);
    expect(found?.status).toBe("active");
  });

  it("terminateSession calls POST /api/sessions/:id/terminate and updates local state", async () => {
    const { api } = await import("../services/api");
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    const session = store.createLocalSession({
      agentType: "chat",
      hostId: "host-1",
    });
    const terminated = { ...session, status: "terminated" };
    vi.mocked(api.post).mockResolvedValueOnce({ session: terminated });

    await store.terminateSession(session.id);

    expect(api.post).toHaveBeenCalledWith(
      `/api/sessions/${session.id}/terminate`,
    );
    const found = store.sessions.find((s) => s.id === session.id);
    expect(found?.status).toBe("terminated");
  });
});
