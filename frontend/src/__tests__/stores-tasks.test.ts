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
  getSocket: vi.fn(() => ({
    onOpen: vi.fn(),
    onClose: vi.fn(),
    onError: vi.fn(),
    channel: vi.fn(),
  })),
}));

const makeTask = (id: string, overrides = {}) => ({
  id,
  sessionId: "sess-1",
  description: `Task ${id}`,
  riskLevel: "read_only" as const,
  status: "pending" as const,
  hostId: "host-1",
  agentId: null,
  createdAt: new Date().toISOString(),
  startedAt: null,
  completedAt: null,
  ...overrides,
});

describe("useTaskStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("is importable and usable", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    expect(store).toBeDefined();
  });

  it("tasks starts as empty array", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    expect(store.tasks).toEqual([]);
  });

  it("loading starts as false", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    expect(store.loading).toBe(false);
  });

  it("blockedTasks is empty when no tasks", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    expect(store.blockedTasks).toEqual([]);
  });

  it("activeTasks is empty when no tasks", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    expect(store.activeTasks).toEqual([]);
  });

  it("blockedTasks returns only blocked tasks", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("t1", { status: "blocked" }));
    store.updateTask(makeTask("t2", { status: "pending" }));
    expect(store.blockedTasks).toHaveLength(1);
    expect(store.blockedTasks[0].id).toBe("t1");
  });

  it("activeTasks returns running and pending tasks", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("t1", { status: "running" }));
    store.updateTask(makeTask("t2", { status: "pending" }));
    store.updateTask(makeTask("t3", { status: "completed" }));
    expect(store.activeTasks).toHaveLength(2);
  });

  it("getTasksForSession filters by session", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("t1", { sessionId: "s1" }));
    store.updateTask(makeTask("t2", { sessionId: "s2" }));
    expect(store.getTasksForSession("s1")).toHaveLength(1);
    expect(store.getTasksForSession("s2")).toHaveLength(1);
    expect(store.getTasksForSession("s3")).toHaveLength(0);
  });

  it("updateTask adds a new task when not found", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("new-t"));
    expect(store.tasks).toHaveLength(1);
    expect(store.tasks[0].id).toBe("new-t");
  });

  it("updateTask replaces existing task in the list", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("upd-t", { status: "pending" }));
    store.updateTask(makeTask("upd-t", { status: "completed" }));
    expect(store.tasks).toHaveLength(1);
    expect(store.tasks[0].status).toBe("completed");
  });

  it("updateTaskStatus changes the status of an existing task", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("status-t", { status: "pending" }));
    store.updateTaskStatus("status-t", "running");
    expect(store.tasks[0].status).toBe("running");
  });

  it("updateTaskStatus does nothing for unknown task id", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    // Should not throw
    expect(() =>
      store.updateTaskStatus("nonexistent", "running"),
    ).not.toThrow();
  });
});
