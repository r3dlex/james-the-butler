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

const makeSession = (overrides = {}) => ({
  id: "sess-1",
  name: "Test Session",
  nameSetByUser: false,
  agentType: "chat" as const,
  hostId: "host-1",
  projectId: null,
  status: "active" as const,
  executionMode: "direct" as const,
  personalityId: null,
  workingDirectories: ["/home/user/project"],
  mcpServers: [],
  keepIntermediates: false,
  tokenCount: 0,
  tokenCost: 0,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString(),
  ...overrides,
});

describe("SessionContextPanel", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("renders host info when session has host data", async () => {
    const { default: SessionContextPanel } =
      await import("../components/session/SessionContextPanel.vue");
    const session = makeSession({ hostId: "host-primary" });
    const wrapper = mount(SessionContextPanel, {
      props: { session },
    });
    expect(wrapper.text()).toContain("host-primary");
  });

  it("renders project link when session belongs to a project", async () => {
    const { default: SessionContextPanel } =
      await import("../components/session/SessionContextPanel.vue");
    const session = makeSession({ projectId: "proj-42" });
    const wrapper = mount(SessionContextPanel, {
      props: { session },
      global: {
        stubs: { RouterLink: { template: "<a><slot /></a>" } },
      },
    });
    expect(wrapper.text()).toContain("proj-42");
  });

  it("execution mode toggle switches between direct and confirmed", async () => {
    const { default: SessionContextPanel } =
      await import("../components/session/SessionContextPanel.vue");
    const session = makeSession({ executionMode: "direct" });
    const wrapper = mount(SessionContextPanel, {
      props: { session },
    });

    // Find the toggle button for execution mode and click it
    const toggleBtn = wrapper.find("[data-testid='execution-mode-toggle']");
    expect(toggleBtn.exists()).toBe(true);

    await toggleBtn.trigger("click");
    const emitted = wrapper.emitted("update:executionMode");
    expect(emitted).toBeTruthy();
    expect(emitted![0]).toEqual(["confirmed"]);
  });

  it("Keep Intermediates toggle emits update event", async () => {
    const { default: SessionContextPanel } =
      await import("../components/session/SessionContextPanel.vue");
    const session = makeSession({ keepIntermediates: false });
    const wrapper = mount(SessionContextPanel, {
      props: { session },
    });

    const keepToggle = wrapper.find(
      "[data-testid='keep-intermediates-toggle']",
    );
    expect(keepToggle.exists()).toBe(true);

    await keepToggle.trigger("click");
    const emitted = wrapper.emitted("update:keepIntermediates");
    expect(emitted).toBeTruthy();
    expect(emitted![0]).toEqual([true]);
  });

  it("shows personality selector with current personality", async () => {
    const { default: SessionContextPanel } =
      await import("../components/session/SessionContextPanel.vue");
    const session = makeSession({ personalityId: "persona-1" });
    const wrapper = mount(SessionContextPanel, {
      props: { session },
    });

    const selector = wrapper.find("[data-testid='personality-selector']");
    expect(selector.exists()).toBe(true);
  });
});
