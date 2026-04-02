import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { api } from "@/services/api";
import { toHumanError } from "@/lib/apiFetch";
import type { ProviderConfig } from "@/types/provider";

export const useProviderStore = defineStore("providers", () => {
  const providers = ref<ProviderConfig[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  const hasVerifiedProvider = computed(() =>
    providers.value.some((p) => p.status === "connected"),
  );

  async function fetchProviders() {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.get<{ providers: ProviderConfig[] }>(
        "/api/providers",
      );
      providers.value = (data.providers || []).map((p) => ({
        ...p,
        models: p.models || [],
      }));
      // Auto-fetch models for each provider in background (no global loading)
      for (const p of providers.value) {
        fetchModels(p.id).catch(() => {});
      }
    } catch (e: unknown) {
      error.value = toHumanError(e, "Failed to fetch providers");
    } finally {
      loading.value = false;
    }
  }

  async function addProvider(
    data: Omit<
      ProviderConfig,
      "id" | "status" | "apiKeyMasked" | "lastTestedAt" | "models"
    > & { apiKey?: string },
  ) {
    loading.value = true;
    error.value = null;
    try {
      const result = await api.post<{ provider: ProviderConfig }>(
        "/api/providers",
        data,
      );
      const added = {
        ...result.provider,
        models: result.provider.models || [],
      };
      providers.value.push(added);
      // Auto-test connection for api_key providers, then fetch models
      if (data.authMethod === "api_key" && data.apiKey) {
        testConnection(added.id).catch(() => {});
      }
      fetchModels(added.id).catch(() => {});
    } catch (e: unknown) {
      error.value = toHumanError(e, "Failed to add provider");
    } finally {
      loading.value = false;
    }
  }

  async function updateProvider(id: string, data: Partial<ProviderConfig>) {
    error.value = null;
    try {
      const result = await api.put<{ provider: ProviderConfig }>(
        `/api/providers/${id}`,
        data,
      );
      const idx = providers.value.findIndex((p) => p.id === id);
      if (idx !== -1)
        providers.value[idx] = {
          ...result.provider,
          models: providers.value[idx].models || [],
        };
    } catch (e: unknown) {
      error.value = toHumanError(e, "Failed to update provider");
    }
  }

  async function removeProvider(id: string) {
    error.value = null;
    try {
      await api.delete(`/api/providers/${id}`);
      providers.value = providers.value.filter((p) => p.id !== id);
    } catch (e: unknown) {
      error.value = toHumanError(e, "Failed to remove provider");
    }
  }

  async function testConnection(
    id: string,
  ): Promise<{ status: string; reason?: string } | null> {
    // No global loading — this runs in background on individual cards
    error.value = null;
    try {
      const result = await api.post<{
        status: string;
        latencyMs?: number;
        reason?: string;
      }>(`/api/providers/${id}/test`);
      const idx = providers.value.findIndex((p) => p.id === id);
      if (idx !== -1) {
        providers.value[idx] = {
          ...providers.value[idx],
          status: (result.status === "connected"
            ? "connected"
            : "failed") as ProviderConfig["status"],
        };
      }
      return { status: result.status, reason: result.reason };
    } catch (e: unknown) {
      const reason = toHumanError(e, "Failed to test connection");
      const idx = providers.value.findIndex((p) => p.id === id);
      if (idx !== -1)
        providers.value[idx] = { ...providers.value[idx], status: "failed" };
      return { status: "failed", reason };
    }
  }

  async function startOAuthFlow(
    providerType: string,
  ): Promise<{ authUrl: string; stateKey: string } | null> {
    error.value = null;
    try {
      const result = await api.post<{ auth_url: string; state_key: string }>(
        "/api/providers/oauth/start",
        { provider_type: providerType },
      );
      return { authUrl: result.auth_url, stateKey: result.state_key };
    } catch (e: unknown) {
      error.value = toHumanError(e, "Failed to start OAuth flow");
      return null;
    }
  }

  async function pollOAuthCompletion(stateKey: string): Promise<boolean> {
    try {
      const result = await api.get<{
        status: string;
        provider?: ProviderConfig;
      }>(`/api/providers/oauth/status/${stateKey}`);
      if (result.status === "completed" && result.provider) {
        providers.value.push({
          ...result.provider,
          models: result.provider.models || [],
        });
        return true;
      }
      return false;
    } catch {
      return false;
    }
  }

  async function fetchModels(id: string) {
    // No global loading — this runs in background
    try {
      const result = await api.get<{ models: string[] }>(
        `/api/providers/${id}/models`,
      );
      const idx = providers.value.findIndex((p) => p.id === id);
      if (idx !== -1)
        providers.value[idx] = {
          ...providers.value[idx],
          models: result.models,
        };
    } catch {
      // Silently fail — models list is non-critical
    }
  }

  return {
    providers,
    loading,
    error,
    hasVerifiedProvider,
    fetchProviders,
    addProvider,
    updateProvider,
    removeProvider,
    testConnection,
    fetchModels,
    startOAuthFlow,
    pollOAuthCompletion,
  };
});
