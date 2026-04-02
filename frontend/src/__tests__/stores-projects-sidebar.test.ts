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
    get: vi.fn().mockResolvedValue({ projects: [] }),
    post: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

const makeProject = (id: string, updatedAt?: string) => ({
  id,
  name: `Project ${id}`,
  description: null,
  executionMode: null,
  repoUrl: null,
  insertedAt: "2026-01-01T00:00:00Z",
  updatedAt: updatedAt ?? "2026-01-01T00:00:00Z",
});

const makeSession = (id: string, projectId: string, updatedAt?: string) => ({
  id,
  name: `Session ${id}`,
  nameSetByUser: false,
  agentType: "chat" as const,
  hostId: "host-1",
  projectId,
  status: "idle" as const,
  executionMode: "direct" as const,
  personalityId: null,
  workingDirectories: [],
  mcpServers: [],
  keepIntermediates: false,
  tokenCount: 0,
  tokenCost: 0,
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt: updatedAt ?? "2026-01-01T00:00:00Z",
});

describe("useProjectStore — sidebar additions", () => {
  beforeEach(() => {
    localStorageMock.clear();
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("recentProjects returns at most 5 projects sorted by updatedAt descending", async () => {
    const { useProjectStore } = await import("../stores/projects");
    const store = useProjectStore();

    const dates = [
      "2026-03-01T00:00:00Z",
      "2026-01-01T00:00:00Z",
      "2026-06-01T00:00:00Z",
      "2026-02-01T00:00:00Z",
      "2026-05-01T00:00:00Z",
      "2026-04-01T00:00:00Z",
    ];
    dates.forEach((d, i) => store.projects.push(makeProject(`p${i + 1}`, d)));

    const recent = store.recentProjects;
    expect(recent).toHaveLength(5);
    // First element should be the most recently updated project
    expect(recent[0].id).toBe("p3"); // June
    expect(recent[1].id).toBe("p5"); // May
    expect(recent[2].id).toBe("p6"); // April
  });

  it("recentProjects returns all projects when fewer than 5 exist", async () => {
    const { useProjectStore } = await import("../stores/projects");
    const store = useProjectStore();
    store.projects.push(makeProject("p1"), makeProject("p2"));
    expect(store.recentProjects).toHaveLength(2);
  });

  it("recentSessionsForProject returns sessions matching projectId sorted desc", async () => {
    const { useProjectStore } = await import("../stores/projects");
    const { useSessionStore } = await import("../stores/sessions");
    const projectStore = useProjectStore();
    const sessionStore = useSessionStore();

    projectStore.projects.push(makeProject("proj-1"));
    sessionStore.sessions.push(
      makeSession("s1", "proj-1", "2026-02-01T00:00:00Z"),
      makeSession("s2", "proj-1", "2026-04-01T00:00:00Z"),
      makeSession("s3", "proj-1", "2026-03-01T00:00:00Z"),
      makeSession("s4", "other-proj", "2026-05-01T00:00:00Z"),
    );

    const sessions = projectStore.recentSessionsForProject("proj-1");
    expect(sessions).toHaveLength(3);
    expect(sessions[0].id).toBe("s2"); // April — most recent
    expect(sessions[1].id).toBe("s3"); // March
    expect(sessions[2].id).toBe("s1"); // February
  });

  it("recentSessionsForProject limits to 3 results", async () => {
    const { useProjectStore } = await import("../stores/projects");
    const { useSessionStore } = await import("../stores/sessions");
    const projectStore = useProjectStore();
    const sessionStore = useSessionStore();

    for (let i = 1; i <= 5; i++) {
      sessionStore.sessions.push(makeSession(`s${i}`, "proj-1"));
    }

    const sessions = projectStore.recentSessionsForProject("proj-1");
    expect(sessions).toHaveLength(3);
  });

  it("recentSessionsForProject returns empty array for unknown project", async () => {
    const { useProjectStore } = await import("../stores/projects");
    const store = useProjectStore();
    expect(store.recentSessionsForProject("nonexistent")).toEqual([]);
  });
});
