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

const makeSession = (
  id: string,
  name = `Session ${id}`,
  updatedAt = "2026-01-01T00:00:00Z",
) => ({
  id,
  name,
  nameSetByUser: false,
  agentType: "chat" as const,
  hostId: "host-1",
  projectId: null,
  status: "idle" as const,
  executionMode: "direct" as const,
  personalityId: null,
  workingDirectories: [],
  mcpServers: [],
  keepIntermediates: false,
  tokenCount: 0,
  tokenCost: 0,
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt,
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

// Stub localStorage so AppSidebar can call getItem/setItem without errors
const localStorageData: Record<string, string> = {};
vi.stubGlobal("localStorage", {
  getItem: (k: string) => localStorageData[k] ?? null,
  setItem: (k: string, v: string) => {
    localStorageData[k] = v;
  },
  removeItem: (k: string) => {
    delete localStorageData[k];
  },
  clear: () => {
    for (const k of Object.keys(localStorageData)) delete localStorageData[k];
  },
  get length() {
    return Object.keys(localStorageData).length;
  },
  key: (i: number) => Object.keys(localStorageData)[i] ?? null,
});

describe("Unified sidebar search", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  describe("SidebarSessionsSection with query prop", () => {
    it("filters sessions using the query prop when provided", async () => {
      const { useSessionStore } = await import("../stores/sessions");
      const store = useSessionStore();
      store.sessions.push(
        makeSession("s1", "Alpha Chat"),
        makeSession("s2", "Beta Work"),
      );

      const { default: SidebarSessionsSection } =
        await import("../components/layout/SidebarSessionsSection.vue");
      const wrapper = mount(SidebarSessionsSection, {
        props: { query: "Alpha" },
        attachTo: document.body,
      });

      expect(wrapper.text()).toContain("Alpha Chat");
      expect(wrapper.text()).not.toContain("Beta Work");
      wrapper.unmount();
    });

    it("shows all sessions when query prop is empty string", async () => {
      const { useSessionStore } = await import("../stores/sessions");
      const store = useSessionStore();
      store.sessions.push(
        makeSession("s1", "Alpha Chat"),
        makeSession("s2", "Beta Work"),
      );

      const { default: SidebarSessionsSection } =
        await import("../components/layout/SidebarSessionsSection.vue");
      const wrapper = mount(SidebarSessionsSection, {
        props: { query: "" },
        attachTo: document.body,
      });

      const text = wrapper.text();
      expect(text).toContain("Alpha Chat");
      expect(text).toContain("Beta Work");
      wrapper.unmount();
    });

    it("hides the internal search input when query prop is provided", async () => {
      const { default: SidebarSessionsSection } =
        await import("../components/layout/SidebarSessionsSection.vue");
      const wrapper = mount(SidebarSessionsSection, {
        props: { query: "test" },
        attachTo: document.body,
      });

      // When query prop is provided, the internal input should be hidden
      const inputs = wrapper.findAll("input");
      expect(inputs.length).toBe(0);
      wrapper.unmount();
    });

    it("never has its own search input (search lives in AppSidebar)", async () => {
      // The internal search was removed — search is now unified in AppSidebar.
      const { default: SidebarSessionsSection } =
        await import("../components/layout/SidebarSessionsSection.vue");
      const wrapper = mount(SidebarSessionsSection, {
        attachTo: document.body,
      });

      const inputs = wrapper.findAll("input");
      expect(inputs.length).toBe(0);
      wrapper.unmount();
    });
  });

  describe("SidebarProjectsSection with query prop", () => {
    it("filters projects using the query prop when provided", async () => {
      const { useProjectStore } = await import("../stores/projects");
      const store = useProjectStore();
      store.projects.push(
        makeProject("p1", "Alpha Project"),
        makeProject("p2", "Beta Project"),
      );

      const { default: SidebarProjectsSection } =
        await import("../components/layout/SidebarProjectsSection.vue");
      const wrapper = mount(SidebarProjectsSection, {
        props: { query: "Alpha" },
        attachTo: document.body,
      });

      expect(wrapper.text()).toContain("Alpha Project");
      expect(wrapper.text()).not.toContain("Beta Project");
      wrapper.unmount();
    });

    it("shows all projects when query prop is empty string", async () => {
      const { useProjectStore } = await import("../stores/projects");
      const store = useProjectStore();
      store.projects.push(
        makeProject("p1", "Alpha Project"),
        makeProject("p2", "Beta Project"),
      );

      const { default: SidebarProjectsSection } =
        await import("../components/layout/SidebarProjectsSection.vue");
      const wrapper = mount(SidebarProjectsSection, {
        props: { query: "" },
        attachTo: document.body,
      });

      const text = wrapper.text();
      expect(text).toContain("Alpha Project");
      expect(text).toContain("Beta Project");
      wrapper.unmount();
    });
  });

  describe("AppSidebar passes search query to both sections", () => {
    it("AppSidebar renders search input in expanded mode", async () => {
      const { default: AppSidebar } =
        await import("../components/layout/AppSidebar.vue");
      const wrapper = mount(AppSidebar, {
        props: { collapsed: false },
        global: {
          stubs: {
            SidebarNavItem: { template: "<div />" },
            SidebarFooter: { template: "<div />" },
            SidebarSessionsSection: {
              template: "<div />",
              props: ["query"],
            },
            SidebarProjectsSection: {
              template: "<div />",
              props: ["query"],
            },
          },
        },
        attachTo: document.body,
      });

      // Should have a search input in expanded sidebar
      const inputs = wrapper.findAll("input[type='text'], input:not([type])");
      expect(inputs.length).toBeGreaterThan(0);
      wrapper.unmount();
    });
  });
});
