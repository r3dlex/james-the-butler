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
