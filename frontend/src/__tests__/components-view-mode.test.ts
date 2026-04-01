// @vitest-environment happy-dom
import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";

vi.mock("../services/api", () => ({
  api: { setToken: vi.fn(), get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));
vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

const makeTask = (overrides = {}) => ({
  id: "task-1",
  sessionId: "sess-1",
  description: "Write unit tests",
  riskLevel: "read_only" as const,
  status: "pending" as const,
  hostId: "host-1",
  agentId: null,
  createdAt: new Date().toISOString(),
  startedAt: null,
  completedAt: null,
  ...overrides,
});

const makeArtifact = (overrides = {}) => ({
  id: "artifact-1",
  sessionId: "sess-1",
  name: "report.pdf",
  type: "document" as const,
  mimeType: "application/pdf",
  url: "/artifacts/report.pdf",
  isDeliverable: true,
  createdAt: new Date().toISOString(),
  ...overrides,
});

const makeSubSession = (overrides = {}) => ({
  id: "sub-1",
  name: "Sub Agent A",
  agentType: "code" as const,
  status: "active" as const,
  ...overrides,
});

describe("ViewModePanel", () => {
  it("panel toggles between tasks and view tabs", async () => {
    const { default: ViewModePanel } =
      await import("../components/session/ViewModePanel.vue");
    const wrapper = mount(ViewModePanel, {
      props: { tasks: [], artifacts: [], subSessions: [] },
    });

    // Initially shows tasks tab
    const tasksTab = wrapper.find("[data-testid='tab-tasks']");
    const viewTab = wrapper.find("[data-testid='tab-view']");
    expect(tasksTab.exists()).toBe(true);
    expect(viewTab.exists()).toBe(true);

    // Click view tab
    await viewTab.trigger("click");

    // Now the view mode panel should be active
    const viewPanel = wrapper.find("[data-testid='view-mode-panel']");
    expect(viewPanel.exists()).toBe(true);
  });

  it("task list tab shows tasks with risk badges", async () => {
    const { default: ViewModePanel } =
      await import("../components/session/ViewModePanel.vue");
    const tasks = [
      makeTask({
        id: "t-1",
        description: "Read config",
        riskLevel: "read_only",
      }),
      makeTask({
        id: "t-2",
        description: "Delete old logs",
        riskLevel: "destructive",
      }),
    ];
    const wrapper = mount(ViewModePanel, {
      props: { tasks, artifacts: [], subSessions: [] },
    });

    // Default tab is tasks
    expect(wrapper.text()).toContain("Read config");
    expect(wrapper.text()).toContain("Delete old logs");
    // Risk badges exist
    expect(wrapper.text()).toContain("Read Only");
    expect(wrapper.text()).toContain("Destructive");
  });

  it("view mode tab shows artifact preview cards", async () => {
    const { default: ViewModePanel } =
      await import("../components/session/ViewModePanel.vue");
    const artifacts = [
      makeArtifact({ id: "a-1", name: "report.pdf" }),
      makeArtifact({ id: "a-2", name: "data.csv", type: "data" }),
    ];
    const wrapper = mount(ViewModePanel, {
      props: { tasks: [], artifacts, subSessions: [] },
    });

    // Switch to view tab
    const viewTab = wrapper.find("[data-testid='tab-view']");
    await viewTab.trigger("click");

    expect(wrapper.text()).toContain("report.pdf");
    expect(wrapper.text()).toContain("data.csv");
  });

  it("multi-agent thumbnail grid renders for active sub-sessions", async () => {
    const { default: ViewModePanel } =
      await import("../components/session/ViewModePanel.vue");
    const subSessions = [
      makeSubSession({ id: "sub-1", name: "Sub Agent A" }),
      makeSubSession({ id: "sub-2", name: "Sub Agent B" }),
    ];
    const wrapper = mount(ViewModePanel, {
      props: { tasks: [], artifacts: [], subSessions },
    });

    // Switch to view tab
    const viewTab = wrapper.find("[data-testid='tab-view']");
    await viewTab.trigger("click");

    const grid = wrapper.find("[data-testid='sub-session-grid']");
    expect(grid.exists()).toBe(true);
    expect(wrapper.text()).toContain("Sub Agent A");
    expect(wrapper.text()).toContain("Sub Agent B");
  });
});
