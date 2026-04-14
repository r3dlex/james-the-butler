// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
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

const mockPost = vi.fn();
vi.mock("@/services/api", () => ({
  api: { setToken: vi.fn(), post: mockPost, get: vi.fn(), delete: vi.fn() },
}));

vi.mock("@/services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
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

describe("useTaskStore — error paths", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    mockPost.mockReset();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("approveTask catches errors and does not throw", async () => {
    mockPost.mockRejectedValueOnce(new Error("Server error"));
    const { useTaskStore } = await import("@/stores/tasks");
    const store = useTaskStore();
    await expect(store.approveTask("task-1")).resolves.not.toThrow();
  });

  it("approveTask does not update tasks on error", async () => {
    mockPost.mockRejectedValueOnce(new Error("Server error"));
    const { useTaskStore } = await import("@/stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("task-1", { status: "pending" }));
    expect(store.tasks).toHaveLength(1);
    await store.approveTask("task-1");
    const task = store.tasks.find((t) => t.id === "task-1");
    expect(task?.status).toBe("pending");
  });

  it("rejectTask catches errors and does not throw", async () => {
    mockPost.mockRejectedValueOnce(new Error("Network error"));
    const { useTaskStore } = await import("@/stores/tasks");
    const store = useTaskStore();
    await expect(store.rejectTask("task-2")).resolves.not.toThrow();
  });

  it("rejectTask does not update tasks on error", async () => {
    mockPost.mockRejectedValueOnce(new Error("Network error"));
    const { useTaskStore } = await import("@/stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("task-2", { status: "pending" }));
    await store.rejectTask("task-2");
    const task = store.tasks.find((t) => t.id === "task-2");
    expect(task?.status).toBe("pending");
  });

  it("approveTask calls POST with correct path", async () => {
    mockPost.mockResolvedValueOnce({
      task: makeTask("task-3", { status: "approved" }),
    });
    const { useTaskStore } = await import("@/stores/tasks");
    const store = useTaskStore();
    await store.approveTask("task-3");
    expect(mockPost).toHaveBeenCalledWith("/api/tasks/task-3/approve", {});
  });

  it("rejectTask calls POST with correct path", async () => {
    mockPost.mockResolvedValueOnce({
      task: makeTask("task-4", { status: "rejected" }),
    });
    const { useTaskStore } = await import("@/stores/tasks");
    const store = useTaskStore();
    await store.rejectTask("task-4");
    expect(mockPost).toHaveBeenCalledWith("/api/tasks/task-4/reject", {});
  });
});
