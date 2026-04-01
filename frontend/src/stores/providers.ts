import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { api } from "@/services/api";
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
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to fetch providers";
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
      providers.value.push({
        ...result.provider,
        models: result.provider.models || [],
      });
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to add provider";
    } finally {
      loading.value = false;
    }
  }

  async function updateProvider(id: string, data: Partial<ProviderConfig>) {
    loading.value = true;
    error.value = null;
    try {
      const result = await api.put<{ provider: ProviderConfig }>(
        `/api/providers/${id}`,
        data,
      );
      const idx = providers.value.findIndex((p) => p.id === id);
      if (idx !== -1) providers.value[idx] = result.provider;
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to update provider";
    } finally {
      loading.value = false;
    }
  }

  async function removeProvider(id: string) {
    loading.value = true;
    error.value = null;
    try {
      await api.delete(`/api/providers/${id}`);
      providers.value = providers.value.filter((p) => p.id !== id);
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to remove provider";
    } finally {
      loading.value = false;
    }
  }

  async function testConnection(id: string) {
    loading.value = true;
    error.value = null;
    try {
      const result = await api.post<{ provider: ProviderConfig }>(
        `/api/providers/${id}/test`,
      );
      const idx = providers.value.findIndex((p) => p.id === id);
      if (idx !== -1) providers.value[idx] = result.provider;
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to test connection";
      const idx = providers.value.findIndex((p) => p.id === id);
      if (idx !== -1)
        providers.value[idx] = { ...providers.value[idx], status: "failed" };
    } finally {
      loading.value = false;
    }
  }

  async function fetchModels(id: string) {
    loading.value = true;
    error.value = null;
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
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to fetch models";
    } finally {
      loading.value = false;
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
  };
});
