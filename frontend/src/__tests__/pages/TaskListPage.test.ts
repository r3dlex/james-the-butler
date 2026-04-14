// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";

vi.mock("@/services/api", () => ({
  api: { setToken: vi.fn(), get: vi.fn(), post: vi.fn(), delete: vi.fn() },
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

describe("TaskListPage — onMounted coverage (2 functions)", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("onMounted calls fetchTasks on the store", async () => {
    const { useTaskStore } = await import("@/stores/tasks");
    const store = useTaskStore();
    const fetchSpy = vi.spyOn(store, "fetchTasks");

    const { default: TaskListPage } = await import("@/pages/TaskListPage.vue");
    mount(TaskListPage, {
      global: {
        stubs: {
          RouterLink: { template: "<a><slot /></a>" },
          LoadingSpinner: { template: "<div>loading</div>" },
          EmptyState: { template: "<div>empty</div>" },
          RiskBadge: { template: "<span></span>" },
          StatusBadge: { template: "<span></span>" },
        },
      },
    });

    expect(fetchSpy).toHaveBeenCalled();
  });

  it("approve button click calls store.approveTask", async () => {
    const { useTaskStore } = await import("@/stores/tasks");
    const store = useTaskStore();
    // Add a pending destructive task so approve/reject buttons appear
    store.updateTask(
      makeTask("t1", { status: "pending", riskLevel: "destructive" }),
    );
    const approveSpy = vi.spyOn(store, "approveTask");

    const { default: TaskListPage } = await import("@/pages/TaskListPage.vue");
    const wrapper = mount(TaskListPage, {
      global: {
        stubs: {
          RouterLink: { template: "<a><slot /></a>" },
          LoadingSpinner: { template: "<div>loading</div>" },
          EmptyState: { template: "<div>empty</div>" },
          RiskBadge: { template: "<span></span>" },
          StatusBadge: { template: "<span></span>" },
        },
      },
    });

    const approveBtn = wrapper
      .findAll("button")
      .find((b) => b.text() === "Approve");
    await approveBtn!.trigger("click");

    expect(approveSpy).toHaveBeenCalledWith("t1");
  });
});
