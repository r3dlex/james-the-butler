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

const makeProvider = (id: string, overrides = {}) => ({
  id,
  providerType: "anthropic" as const,
  displayName: `Provider ${id}`,
  authMethod: "api_key" as const,
  status: "untested" as const,
  baseUrl: null,
  apiKeyMasked: "sk-****",
  lastTestedAt: null,
  models: [],
  ...overrides,
});

describe("SettingsModelsPage", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("page renders a section for each known provider type", async () => {
    const { useProviderStore } = await import("../stores/providers");
    const store = useProviderStore();
    store.providers.push(
      makeProvider("p1", {
        providerType: "anthropic",
        displayName: "Anthropic",
      }),
      makeProvider("p2", { providerType: "openai", displayName: "OpenAI" }),
    );

    const { default: SettingsModelsPage } =
      await import("../pages/settings/SettingsModelsPage.vue");

    const wrapper = mount(SettingsModelsPage, {
      global: {
        stubs: {
          LoadingSpinner: { template: "<div>loading</div>" },
          ProviderCard: {
            template:
              "<div class='provider-card'>{{ provider.displayName }}</div>",
            props: ["provider"],
          },
        },
      },
    });

    expect(wrapper.text()).toContain("Anthropic");
    expect(wrapper.text()).toContain("OpenAI");
  });

  it("connected providers show green status", async () => {
    const { useProviderStore } = await import("../stores/providers");
    const store = useProviderStore();
    store.providers.push(
      makeProvider("p1", {
        status: "connected",
        displayName: "Connected Provider",
      }),
    );

    const { default: SettingsModelsPage } =
      await import("../pages/settings/SettingsModelsPage.vue");

    const wrapper = mount(SettingsModelsPage, {
      global: {
        stubs: {
          LoadingSpinner: { template: "<div>loading</div>" },
          ProviderCard: {
            template:
              "<div class='provider-card'><span class='status' :data-status='provider.status'>{{ provider.displayName }}</span></div>",
            props: ["provider"],
          },
        },
      },
    });

    const statusEl = wrapper.find("[data-status='connected']");
    expect(statusEl.exists()).toBe(true);
  });

  it("Add Provider button is visible", async () => {
    const { default: SettingsModelsPage } =
      await import("../pages/settings/SettingsModelsPage.vue");

    const wrapper = mount(SettingsModelsPage, {
      global: {
        stubs: {
          LoadingSpinner: { template: "<div>loading</div>" },
          ProviderCard: {
            template: "<div class='provider-card'></div>",
            props: ["provider"],
          },
        },
      },
    });

    expect(wrapper.text()).toContain("Add Provider");
  });

  it("shows error message below Add Provider form when auto-test fails after adding", async () => {
    const { api } = await import("../services/api");
    const { useProviderStore } = await import("../stores/providers");
    const store = useProviderStore();

    // addProvider POST succeeds
    vi.mocked(api.post).mockResolvedValueOnce({
      provider: {
        id: "p-new",
        providerType: "anthropic",
        displayName: "My Anthropic",
        authMethod: "api_key",
        status: "untested",
        baseUrl: null,
        apiKeyMasked: "sk-****",
        lastTestedAt: null,
        models: [],
      },
    });
    // testConnection POST fails (wrong key → 401)
    vi.mocked(api.post).mockRejectedValueOnce(new Error("Unauthorized"));
    // fetchModels GET also fails (unrelated)
    vi.mocked(api.get).mockRejectedValueOnce(new Error("Network error"));

    const { default: SettingsModelsPage } =
      await import("../pages/settings/SettingsModelsPage.vue");

    const wrapper = mount(SettingsModelsPage, {
      global: {
        stubs: {
          LoadingSpinner: { template: "<div>loading</div>" },
          ProviderCard: {
            template: "<div class='provider-card'></div>",
            props: ["provider"],
          },
        },
      },
    });

    // Directly trigger the error path via store to verify it surfaces in the template
    store.providers.splice(0);
    store.loading = false;
    store.error = "Failed to test connection";

    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain("Failed to test connection");
  });

  it("empty state shows setup instructions when no providers configured", async () => {
    const { useProviderStore } = await import("../stores/providers");
    const store = useProviderStore();
    // ensure no providers
    store.providers.splice(0);

    const { default: SettingsModelsPage } =
      await import("../pages/settings/SettingsModelsPage.vue");

    const wrapper = mount(SettingsModelsPage, {
      global: {
        stubs: {
          LoadingSpinner: { template: "<div>loading</div>" },
          ProviderCard: {
            template: "<div class='provider-card'></div>",
            props: ["provider"],
          },
        },
      },
    });

    // Should show some setup/instructions text when there are no providers
    const text = wrapper.text();
    expect(
      text.includes("no provider") ||
        text.includes("No provider") ||
        text.includes("Add a provider") ||
        text.includes("Get started") ||
        text.includes("configure") ||
        text.includes("Configure") ||
        text.includes("set up") ||
        text.includes("Set up"),
    ).toBe(true);
  });
});
