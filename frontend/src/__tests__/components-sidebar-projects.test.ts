// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";

vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn().mockResolvedValue({ projects: [], sessions: [] }),
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

const makeProject = (id: string, name = `Project ${id}`) => ({
  id,
  name,
  description: null,
  executionMode: null,
  repoUrl: null,
  insertedAt: "2026-01-01T00:00:00Z",
  updatedAt: "2026-01-01T00:00:00Z",
});

const makeSession = (
  id: string,
  projectId: string,
  name = `Session ${id}`,
) => ({
  id,
  name,
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
  updatedAt: "2026-01-01T00:00:00Z",
});

describe("SidebarProjectsSection", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  async function mountComponent() {
    const { default: SidebarProjectsSection } =
      await import("../components/layout/SidebarProjectsSection.vue");
    return mount(SidebarProjectsSection, {
      attachTo: document.body,
    });
  }

  it("renders a 'More →' link to /projects", async () => {
    const wrapper = await mountComponent();
    const text = wrapper.text();
    expect(text).toMatch(/more/i);
    wrapper.unmount();
  });

  it("renders a '+ New Project' button", async () => {
    const wrapper = await mountComponent();
    const text = wrapper.text();
    expect(text).toMatch(/new project/i);
    wrapper.unmount();
  });

  it("shows project names from the store", async () => {
    const { useProjectStore } = await import("../stores/projects");
    const store = useProjectStore();
    store.projects.push(makeProject("p1", "Alpha"), makeProject("p2", "Beta"));

    const wrapper = await mountComponent();
    const text = wrapper.text();
    expect(text).toContain("Alpha");
    expect(text).toContain("Beta");
    wrapper.unmount();
  });

  it("shows sessions under each project", async () => {
    const { useProjectStore } = await import("../stores/projects");
    const { useSessionStore } = await import("../stores/sessions");
    const projectStore = useProjectStore();
    const sessionStore = useSessionStore();

    projectStore.projects.push(makeProject("p1", "Alpha"));
    sessionStore.sessions.push(makeSession("s1", "p1", "Chat One"));

    const wrapper = await mountComponent();
    expect(wrapper.text()).toContain("Chat One");
    wrapper.unmount();
  });

  it("shows empty state when no projects exist", async () => {
    const wrapper = await mountComponent();
    const text = wrapper.text();
    // Should still render the header / buttons even with no projects
    expect(text).toMatch(/new project/i);
    wrapper.unmount();
  });
});
