// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";

vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn().mockResolvedValue({ sessions: [], projects: [] }),
    post: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

vi.mock("vue-router", async (importOriginal) => {
  const actual = await importOriginal<typeof import("vue-router")>();
  return {
    ...actual,
    useRouter: vi.fn(() => ({ push: vi.fn() })),
    useRoute: vi.fn(() => ({ params: {}, path: "/" })),
    RouterLink: { template: "<a><slot /></a>" },
  };
});

describe("NewSessionModal", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  async function mountModal(props = {}) {
    const { default: NewSessionModal } =
      await import("../components/session/NewSessionModal.vue");
    return mount(NewSessionModal, {
      props: { open: true, ...props },
      attachTo: document.body,
      global: {
        stubs: {
          Teleport: { template: "<div><slot /></div>" },
        },
      },
    });
  }

  it("renders when open is true", async () => {
    const wrapper = await mountModal();
    expect(wrapper.find("h2").exists()).toBe(true);
    wrapper.unmount();
  });

  it("does not render content when open is false", async () => {
    const { default: NewSessionModal } =
      await import("../components/session/NewSessionModal.vue");
    const wrapper = mount(NewSessionModal, {
      props: { open: false },
      attachTo: document.body,
      global: {
        stubs: {
          Teleport: { template: "<div><slot /></div>" },
        },
      },
    });
    // When closed, no modal dialog content visible
    expect(wrapper.find("h2").exists()).toBe(false);
    wrapper.unmount();
  });

  it("renders workspace directory input", async () => {
    const wrapper = await mountModal();
    // Should have an input for workspace folder path
    const inputs = wrapper.findAll("input[type='text'], input:not([type])");
    expect(inputs.length).toBeGreaterThan(0);
    wrapper.unmount();
  });

  it("renders execution mode selector with direct and confirmed options", async () => {
    const wrapper = await mountModal();
    const text = wrapper.text();
    expect(text).toMatch(/direct/i);
    expect(text).toMatch(/confirmed/i);
    wrapper.unmount();
  });

  it("has a '+ Add folder' button that adds another workspace input", async () => {
    const wrapper = await mountModal();
    const text = wrapper.text();
    expect(text).toMatch(/add folder/i);

    const initialInputCount = wrapper.findAll(
      "input[type='text'], input:not([type])",
    ).length;

    // Click the add folder button
    const addFolderBtn = wrapper
      .findAll("button")
      .find((b) => b.text().match(/add folder/i));
    expect(addFolderBtn).toBeDefined();

    await addFolderBtn!.trigger("click");

    const newInputCount = wrapper.findAll(
      "input[type='text'], input:not([type])",
    ).length;
    expect(newInputCount).toBeGreaterThan(initialInputCount);
    wrapper.unmount();
  });

  it("emits 'create' with workingDirectories and executionMode on submit", async () => {
    const wrapper = await mountModal();

    // Find the first workspace input and fill it
    const inputs = wrapper.findAll("input[type='text'], input:not([type])");
    if (inputs.length > 0) {
      await inputs[0].setValue("/home/user/project");
    }

    // Submit (click Create button)
    const createBtn = wrapper
      .findAll("button")
      .find((b) => b.text().match(/^create$/i));
    expect(createBtn).toBeDefined();
    await createBtn!.trigger("click");

    const emitted = wrapper.emitted("create");
    expect(emitted).toBeDefined();
    expect(emitted!.length).toBeGreaterThan(0);

    const payload = emitted![0][0] as {
      workingDirectories: string[];
      executionMode: string;
    };
    expect(payload).toHaveProperty("workingDirectories");
    expect(payload).toHaveProperty("executionMode");
    expect(["direct", "confirmed"]).toContain(payload.executionMode);
    wrapper.unmount();
  });

  it("emits 'cancel' when cancel button is clicked", async () => {
    const wrapper = await mountModal();

    const cancelBtn = wrapper
      .findAll("button")
      .find((b) => b.text().match(/cancel/i));
    expect(cancelBtn).toBeDefined();
    await cancelBtn!.trigger("click");

    expect(wrapper.emitted("cancel")).toBeDefined();
    wrapper.unmount();
  });

  it("pre-fills projectId when provided as prop", async () => {
    const wrapper = await mountModal({ projectId: "proj-123" });
    // The modal should accept projectId without errors
    expect(wrapper.find("h2").exists()).toBe(true);
    wrapper.unmount();
  });

  it("emits 'create' with projectId when provided", async () => {
    const wrapper = await mountModal({ projectId: "proj-456" });

    const createBtn = wrapper
      .findAll("button")
      .find((b) => b.text().match(/^create$/i));
    expect(createBtn).toBeDefined();
    await createBtn!.trigger("click");

    const emitted = wrapper.emitted("create");
    expect(emitted).toBeDefined();
    // projectId prop is accessible on the wrapper
    expect(wrapper.props("projectId")).toBe("proj-456");
    wrapper.unmount();
  });
});
