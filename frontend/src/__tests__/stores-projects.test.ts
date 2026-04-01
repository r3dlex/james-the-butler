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

describe("useProjectStore", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("loads project list from API", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");

    const mockProjects = [
      {
        id: "p1",
        name: "Project Alpha",
        description: "First project",
        executionMode: "direct",
        repoUrl: null,
        insertedAt: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z",
      },
      {
        id: "p2",
        name: "Project Beta",
        description: null,
        executionMode: null,
        repoUrl: "https://github.com/org/beta",
        insertedAt: "2024-01-02T00:00:00Z",
        updatedAt: "2024-01-02T00:00:00Z",
      },
    ];
    vi.mocked(api.get).mockResolvedValueOnce({ projects: mockProjects });

    const store = useProjectStore();
    await store.fetchProjects();

    expect(api.get).toHaveBeenCalledWith("/api/projects");
    expect(store.projects).toEqual(mockProjects);
    expect(store.loading).toBe(false);
    expect(store.error).toBeNull();
  });

  it("loads single project by ID", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");

    const mockProject = {
      id: "p1",
      name: "Project Alpha",
      description: "A fine project",
      executionMode: "direct",
      repoUrl: null,
      insertedAt: "2024-01-01T00:00:00Z",
      updatedAt: "2024-01-01T00:00:00Z",
    };
    vi.mocked(api.get).mockResolvedValueOnce({ project: mockProject });

    const store = useProjectStore();
    await store.fetchProject("p1");

    expect(api.get).toHaveBeenCalledWith("/api/projects/p1");
    expect(store.currentProject).toEqual(mockProject);
    expect(store.loading).toBe(false);
    expect(store.error).toBeNull();
  });

  it("loads sessions for a project", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");

    const mockSessions = [
      {
        id: "s1",
        name: "Session One",
        agentType: "chat",
        status: "active",
        lastUsedAt: "2024-01-05T10:00:00Z",
      },
      {
        id: "s2",
        name: "Session Two",
        agentType: "code",
        status: "completed",
        lastUsedAt: null,
      },
    ];
    vi.mocked(api.get).mockResolvedValueOnce({ sessions: mockSessions });

    const store = useProjectStore();
    await store.fetchProjectSessions("p1");

    expect(api.get).toHaveBeenCalledWith("/api/projects/p1/sessions");
    expect(store.currentProjectSessions).toEqual(mockSessions);
    expect(store.loading).toBe(false);
    expect(store.error).toBeNull();
  });

  it("handles API errors from fetchProjects gracefully", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");

    vi.mocked(api.get).mockRejectedValueOnce({ error: "Unauthorized" });

    const store = useProjectStore();
    await store.fetchProjects();

    expect(store.projects).toEqual([]);
    expect(store.loading).toBe(false);
    expect(store.error).toBe("Unauthorized");
  });

  it("handles API errors from fetchProject gracefully", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");

    vi.mocked(api.get).mockRejectedValueOnce({ error: "Not found" });

    const store = useProjectStore();
    await store.fetchProject("nonexistent");

    expect(store.currentProject).toBeNull();
    expect(store.loading).toBe(false);
    expect(store.error).toBe("Not found");
  });

  it("handles API errors from fetchProjectSessions gracefully", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");

    vi.mocked(api.get).mockRejectedValueOnce({ error: "Server error" });

    const store = useProjectStore();
    await store.fetchProjectSessions("p1");

    expect(store.currentProjectSessions).toEqual([]);
    expect(store.loading).toBe(false);
    expect(store.error).toBe("Server error");
  });
});
