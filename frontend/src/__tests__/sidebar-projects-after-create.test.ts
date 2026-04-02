// @vitest-environment happy-dom
/**
 * TDD tests for Issue 3: Projects appear in sidebar after creation.
 *
 * The sidebar (SidebarProjectsSection) reads from projectStore.recentProjects.
 * After createProject(), the new project must appear in projectStore.projects
 * so the sidebar renders it.
 *
 * Root cause: ProjectListPage.vue uses a local `projects` ref instead of
 * the projectStore, so new projects are never added to the store.
 * Fix: projectStore must expose a createProject() action and ProjectListPage
 * must call it.
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
    get: vi.fn().mockResolvedValue({ projects: [] }),
    post: vi.fn(),
    delete: vi.fn(),
    put: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

const makeProject = (id: string) => ({
  id,
  name: `Project ${id}`,
  description: null,
  executionMode: null,
  repoUrl: null,
  insertedAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  sessionCount: 0,
});

describe("Project sidebar visibility after creation", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("projectStore exposes a createProject() action", async () => {
    const { useProjectStore } = await import("../stores/projects");
    const store = useProjectStore();
    expect(typeof store.createProject).toBe("function");
  });

  it("after createProject() API success, recentProjects includes the new project", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");
    const store = useProjectStore();

    const newProject = makeProject("new-project-1");
    vi.mocked(api.post).mockResolvedValueOnce({ project: newProject });

    const result = await store.createProject({ name: "New Project Alpha" });

    expect(result).not.toBeNull();
    expect(result?.id).toBe("new-project-1");

    // The project must be in recentProjects for the sidebar to show it
    const ids = store.recentProjects.map((p) => p.id);
    expect(ids).toContain("new-project-1");
  });

  it("after createProject() API failure, store projects list is unchanged", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");
    const store = useProjectStore();

    vi.mocked(api.post).mockRejectedValueOnce(new Error("Network error"));

    const result = await store.createProject({ name: "Failed Project" });

    // Should return null on failure
    expect(result).toBeNull();
    expect(store.projects).toEqual([]);
  });

  it("createProject() posts to /api/projects with the correct payload", async () => {
    const { api } = await import("../services/api");
    const { useProjectStore } = await import("../stores/projects");
    const store = useProjectStore();

    vi.mocked(api.post).mockResolvedValueOnce({
      project: makeProject("p-test"),
    });

    await store.createProject({
      name: "Test Project",
      workingDirectories: ["/home/user/test"],
    });

    expect(api.post).toHaveBeenCalledWith("/api/projects", {
      name: "Test Project",
      working_directories: ["/home/user/test"],
    });
  });
});
