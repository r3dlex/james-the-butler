// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";

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

const mockFetchCurrentUser = vi.fn().mockResolvedValue(undefined);
const mockFetchProviders = vi.fn().mockResolvedValue(undefined);
const mockFetchSessions = vi.fn().mockResolvedValue(undefined);
const mockFetchProjects = vi.fn().mockResolvedValue(undefined);

vi.mock("../stores/auth", () => ({
  useAuthStore: vi.fn(() => ({
    isAuthenticated: true,
    fetchCurrentUser: mockFetchCurrentUser,
  })),
}));

vi.mock("../stores/providers", () => ({
  useProviderStore: vi.fn(() => ({
    fetchProviders: mockFetchProviders,
  })),
}));

vi.mock("../stores/sessions", () => ({
  useSessionStore: vi.fn(() => ({
    fetchSessions: mockFetchSessions,
  })),
}));

vi.mock("../stores/projects", () => ({
  useProjectStore: vi.fn(() => ({
    fetchProjects: mockFetchProjects,
  })),
}));

vi.mock("vue-router", async (importOriginal) => {
  const actual = await importOriginal<typeof import("vue-router")>();
  return {
    ...actual,
    useRouter: vi.fn(() => ({ push: vi.fn() })),
    useRoute: vi.fn(() => ({ params: {}, path: "/" })),
    RouterLink: { template: "<a><slot /></a>" },
    RouterView: { template: "<div />" },
  };
});

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

describe("App bootstrap data loading", () => {
  beforeEach(() => {
    localStorageMock.clear();
    vi.clearAllMocks();
    // Reset to authenticated state
    mockFetchCurrentUser.mockResolvedValue(undefined);
    mockFetchProviders.mockResolvedValue(undefined);
    mockFetchSessions.mockResolvedValue(undefined);
    mockFetchProjects.mockResolvedValue(undefined);
  });

  it("calls fetchSessions when authenticated on mount", async () => {
    const { mount } = await import("@vue/test-utils");
    const { createPinia, setActivePinia } = await import("pinia");
    setActivePinia(createPinia());

    // Re-mock useAuthStore for this test to return authenticated
    const { useAuthStore } = await import("../stores/auth");
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (useAuthStore as unknown as ReturnType<typeof vi.fn>).mockReturnValue({
      isAuthenticated: true,
      fetchCurrentUser: mockFetchCurrentUser,
    });

    const { default: App } = await import("../App.vue");

    // AppShell may not be available — use a simple stub approach
    const wrapper = mount(App, {
      global: {
        stubs: {
          AppShell: { template: "<div><slot /></div>" },
          RouterView: { template: "<div />" },
        },
      },
    });

    // Wait for onMounted to complete
    await new Promise((r) => setTimeout(r, 50));

    expect(mockFetchSessions).toHaveBeenCalled();
    wrapper.unmount();
  });

  it("calls fetchProjects when authenticated on mount", async () => {
    const { mount } = await import("@vue/test-utils");
    const { createPinia, setActivePinia } = await import("pinia");
    setActivePinia(createPinia());

    const { useAuthStore } = await import("../stores/auth");
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (useAuthStore as unknown as ReturnType<typeof vi.fn>).mockReturnValue({
      isAuthenticated: true,
      fetchCurrentUser: mockFetchCurrentUser,
    });

    const { default: App } = await import("../App.vue");

    const wrapper = mount(App, {
      global: {
        stubs: {
          AppShell: { template: "<div><slot /></div>" },
          RouterView: { template: "<div />" },
        },
      },
    });

    await new Promise((r) => setTimeout(r, 50));

    expect(mockFetchProjects).toHaveBeenCalled();
    wrapper.unmount();
  });
});
