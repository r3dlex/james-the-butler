// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";

vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
}));

const makeProvider = (overrides = {}) => ({
  id: "p1",
  providerType: "anthropic" as const,
  displayName: "Anthropic",
  authMethod: "api_key" as const,
  status: "untested" as const,
  baseUrl: null,
  apiKeyMasked: "sk-****",
  lastTestedAt: null,
  models: [],
  ...overrides,
});

describe("ProviderCard", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("renders provider display name", async () => {
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");
    const provider = makeProvider({ displayName: "My Anthropic" });

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    expect(wrapper.text()).toContain("My Anthropic");
  });

  it("shows green dot for connected status", async () => {
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");
    const provider = makeProvider({ status: "connected" });

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    const dot = wrapper.find(".status-dot");
    expect(dot.classes()).toContain("bg-green-500");
  });

  it("shows yellow dot for untested status", async () => {
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");
    const provider = makeProvider({ status: "untested" });

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    const dot = wrapper.find(".status-dot");
    expect(dot.classes()).toContain("bg-yellow-400");
  });

  it("shows red dot for failed status", async () => {
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");
    const provider = makeProvider({ status: "failed" });

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    const dot = wrapper.find(".status-dot");
    expect(dot.classes()).toContain("bg-red-500");
  });

  it("Test Connection button triggers testConnection and shows loading state", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");

    const provider = makeProvider({ status: "untested" });
    const updated = { ...provider, status: "connected" as const };

    let resolveTest!: (val: unknown) => void;
    const testPromise = new Promise((resolve) => {
      resolveTest = resolve;
    });
    vi.mocked(api.post).mockReturnValueOnce(
      testPromise as Promise<{ provider: typeof updated }>,
    );

    const store = useProviderStore();
    store.providers.push(provider);

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    const testBtn = wrapper.find("button");
    await testBtn.trigger("click");

    // While loading, button shows loading indicator
    expect(wrapper.text()).toContain("...");

    // Resolve the promise
    resolveTest({ provider: updated });
    await new Promise((r) => setTimeout(r, 0));

    expect(api.post).toHaveBeenCalledWith("/api/providers/p1/test");
  });

  it("Configure button emits configure event", async () => {
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");
    const provider = makeProvider();

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    const buttons = wrapper.findAll("button");
    const configureBtn = buttons.find((b) => b.text() === "Configure");
    expect(configureBtn).toBeTruthy();
    await configureBtn!.trigger("click");

    expect(wrapper.emitted("configure")).toBeTruthy();
    expect(wrapper.emitted("configure")![0]).toEqual([provider]);
  });

  it("models list renders when models are loaded", async () => {
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");
    const provider = makeProvider({
      models: ["claude-opus-4", "claude-sonnet-4"],
    });

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    expect(wrapper.text()).toContain("claude-opus-4");
    expect(wrapper.text()).toContain("claude-sonnet-4");
  });

  it("shows No models when models array is empty", async () => {
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");
    const provider = makeProvider({ models: [] });

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    expect(wrapper.text()).toContain("No models");
  });

  it("renders without crashing when models is undefined (API response without models field)", async () => {
    const { default: ProviderCard } =
      await import("../components/settings/ProviderCard.vue");
    // Simulate API response that has no models field at all
    const provider = makeProvider();
    delete (provider as Record<string, unknown>).models;

    const wrapper = mount(ProviderCard, {
      props: { provider },
    });

    // Should render without throwing, and show "No models"
    expect(wrapper.text()).toContain("No models");
    expect(wrapper.text()).toContain("Anthropic");
  });
});
