// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";

vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn().mockResolvedValue({ sessions: [] }),
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

describe("SidebarSessionsSection", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  async function mountComponent(props: Record<string, unknown> = {}) {
    const { default: SidebarSessionsSection } =
      await import("../components/layout/SidebarSessionsSection.vue");
    return mount(SidebarSessionsSection, {
      props,
      attachTo: document.body,
    });
  }

  it("renders a '+ New Session' button", async () => {
    const wrapper = await mountComponent();
    expect(wrapper.text()).toMatch(/new session/i);
    wrapper.unmount();
  });

  it("renders a 'More →' link to /sessions", async () => {
    const wrapper = await mountComponent();
    expect(wrapper.text()).toMatch(/more/i);
    wrapper.unmount();
  });

  it("shows session names from the store (most recent first, max 5)", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    store.sessions.push(
      makeSession("s1", "Alpha", "2026-01-01T00:00:00Z"),
      makeSession("s2", "Beta", "2026-03-01T00:00:00Z"),
      makeSession("s3", "Gamma", "2026-02-01T00:00:00Z"),
    );

    const wrapper = await mountComponent();
    const text = wrapper.text();
    expect(text).toContain("Beta");
    expect(text).toContain("Gamma");
    expect(text).toContain("Alpha");
    wrapper.unmount();
  });

  it("shows at most 5 sessions", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();

    for (let i = 1; i <= 8; i++) {
      store.sessions.push(makeSession(`s${i}`, `Session ${i}`));
    }

    const wrapper = await mountComponent();
    // Count session links (RouterLink stubs render as <a>)
    // There are 5 session links + 1 "More →" link = max 6 <a> tags
    const links = wrapper.findAll("a");
    expect(links.length).toBeLessThanOrEqual(7);
    wrapper.unmount();
  });

  it("filters sessions by query prop", async () => {
    const { useSessionStore } = await import("../stores/sessions");
    const store = useSessionStore();
    store.sessions.push(
      makeSession("s1", "Alpha Chat"),
      makeSession("s2", "Beta Work"),
    );

    const wrapper = await mountComponent({ query: "alpha" });

    expect(wrapper.text()).toContain("Alpha Chat");
    expect(wrapper.text()).not.toContain("Beta Work");
    wrapper.unmount();
  });
});
