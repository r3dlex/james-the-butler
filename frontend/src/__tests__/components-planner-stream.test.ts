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

const makeStep = (overrides = {}) => ({
  type: "task_created",
  description: "Run tests",
  riskLevel: "read_only" as const,
  taskId: "t-1",
  ...overrides,
});

describe("PlannerReasoningStream", () => {
  it("renders 'Analyzing...' during decomposing state", async () => {
    const { default: PlannerReasoningStream } =
      await import("../components/session/PlannerReasoningStream.vue");
    const wrapper = mount(PlannerReasoningStream, {
      props: {
        plannerSteps: [],
        plannerState: "decomposing",
        executionMode: "direct",
      },
    });
    expect(wrapper.text()).toContain("Analyzing");
  });

  it("renders task cards as planner events arrive", async () => {
    const { default: PlannerReasoningStream } =
      await import("../components/session/PlannerReasoningStream.vue");
    const steps = [
      makeStep({ description: "Read config files", riskLevel: "read_only" }),
      makeStep({
        description: "Install dependencies",
        riskLevel: "additive",
        taskId: "t-2",
      }),
    ];
    const wrapper = mount(PlannerReasoningStream, {
      props: {
        plannerSteps: steps,
        plannerState: "decomposing",
        executionMode: "direct",
      },
    });
    expect(wrapper.text()).toContain("Read config files");
    expect(wrapper.text()).toContain("Install dependencies");
  });

  it("hides planner stream when agent response begins (state changes to executing)", async () => {
    const { default: PlannerReasoningStream } =
      await import("../components/session/PlannerReasoningStream.vue");
    const steps = [makeStep({ description: "Some task" })];
    const wrapper = mount(PlannerReasoningStream, {
      props: {
        plannerSteps: steps,
        plannerState: "executing",
        executionMode: "direct",
      },
    });
    // When state is "executing", the planner stream panel should not be visible
    const panel = wrapper.find("[data-testid='planner-stream-panel']");
    expect(panel.exists()).toBe(false);
  });

  it("shows approval button for destructive tasks in confirmed mode", async () => {
    const { default: PlannerReasoningStream } =
      await import("../components/session/PlannerReasoningStream.vue");
    const steps = [
      makeStep({
        description: "Delete old logs",
        riskLevel: "destructive",
        taskId: "t-3",
      }),
    ];
    const wrapper = mount(PlannerReasoningStream, {
      props: {
        plannerSteps: steps,
        plannerState: "awaiting_approval",
        executionMode: "confirmed",
      },
    });
    const approveBtn = wrapper.find("[data-testid='approve-btn']");
    expect(approveBtn.exists()).toBe(true);
  });
});
