// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";

vi.mock("../services/api", () => ({
  api: { setToken: vi.fn(), get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));
vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

const makeTask = (id: string, overrides: Record<string, unknown> = {}) => ({
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

describe("TaskListPage — rendering", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("renders tasks grouped by session", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("t1", { sessionId: "sess-1" }));
    store.updateTask(makeTask("t2", { sessionId: "sess-1" }));
    store.updateTask(makeTask("t3", { sessionId: "sess-2" }));

    const { default: TaskListPage } = await import("../pages/TaskListPage.vue");
    const wrapper = mount(TaskListPage, {
      global: {
        stubs: {
          RouterLink: { template: "<a><slot /></a>" },
          LoadingSpinner: { template: "<div>loading</div>" },
          EmptyState: { template: "<div>empty</div>" },
          RiskBadge: { template: "<span class='risk-badge'></span>" },
          StatusBadge: { template: "<span class='status-badge'></span>" },
        },
      },
    });

    // All three tasks should appear
    expect(wrapper.text()).toContain("Task t1");
    expect(wrapper.text()).toContain("Task t2");
    expect(wrapper.text()).toContain("Task t3");
  });

  it("shows risk level badge for each task", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("r1", { riskLevel: "read_only" }));
    store.updateTask(makeTask("r2", { riskLevel: "additive" }));
    store.updateTask(makeTask("r3", { riskLevel: "destructive" }));

    const { default: TaskListPage } = await import("../pages/TaskListPage.vue");
    const wrapper = mount(TaskListPage, {
      global: {
        stubs: {
          RouterLink: { template: "<a><slot /></a>" },
          LoadingSpinner: { template: "<div>loading</div>" },
          EmptyState: { template: "<div>empty</div>" },
          RiskBadge: {
            template: "<span class='risk-badge' :data-level='level'></span>",
            props: ["level"],
          },
          StatusBadge: { template: "<span class='status-badge'></span>" },
        },
      },
    });

    const badges = wrapper.findAll(".risk-badge");
    expect(badges.length).toBe(3);

    const levels = badges.map((b) => b.attributes("data-level"));
    expect(levels).toContain("read_only");
    expect(levels).toContain("additive");
    expect(levels).toContain("destructive");
  });

  it("completed tasks have line-through / strikethrough styling class", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    store.updateTask(makeTask("done", { status: "completed" }));
    store.updateTask(makeTask("active", { status: "running" }));

    const { default: TaskListPage } = await import("../pages/TaskListPage.vue");
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

    // Find the element that shows task descriptions and check for line-through class
    const strikethrough = wrapper.find(".line-through");
    expect(strikethrough.exists()).toBe(true);
    expect(strikethrough.text()).toContain("Task done");
  });

  it("tasks are ordered with active first, completed at bottom", async () => {
    const { useTaskStore } = await import("../stores/tasks");
    const store = useTaskStore();
    // Add in mixed order
    store.updateTask(
      makeTask("c1", { status: "completed", description: "Completed Task" }),
    );
    store.updateTask(
      makeTask("a1", { status: "running", description: "Active Task" }),
    );
    store.updateTask(
      makeTask("p1", { status: "pending", description: "Pending Task" }),
    );

    const { default: TaskListPage } = await import("../pages/TaskListPage.vue");
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

    const text = wrapper.text();
    const activeIdx = text.indexOf("Active Task");
    const pendingIdx = text.indexOf("Pending Task");
    const completedIdx = text.indexOf("Completed Task");

    // Active and pending tasks appear before completed tasks
    expect(activeIdx).toBeGreaterThanOrEqual(0);
    expect(completedIdx).toBeGreaterThanOrEqual(0);
    expect(completedIdx).toBeGreaterThan(activeIdx);
    expect(completedIdx).toBeGreaterThan(pendingIdx);
  });
});
