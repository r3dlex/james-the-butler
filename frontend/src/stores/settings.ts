import { defineStore } from "pinia";
import { ref } from "vue";
import { api } from "@/services/api";
import type { ModelConfig } from "@/types/model";
import type { McpServer } from "@/types/mcp";

export const useSettingsStore = defineStore("settings", () => {
  const modelConfig = ref<ModelConfig | null>(null);
  const mcpServers = ref<McpServer[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchModelConfig() {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.get<{ modelConfig: ModelConfig }>(
        "/api/settings/model_config",
      );
      modelConfig.value = data.modelConfig;
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to fetch model config";
    } finally {
      loading.value = false;
    }
  }

  async function saveModelConfig(config: Partial<ModelConfig>) {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.put<{ modelConfig: ModelConfig }>(
        "/api/settings/model_config",
        config,
      );
      modelConfig.value = data.modelConfig;
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to save model config";
    } finally {
      loading.value = false;
    }
  }

  async function fetchMcpServers() {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.get<{ mcpServers: McpServer[] }>(
        "/api/settings/mcp_servers",
      );
      mcpServers.value = data.mcpServers;
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to fetch MCP servers";
    } finally {
      loading.value = false;
    }
  }

  async function addMcpServer(server: Omit<McpServer, "id" | "status">) {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.post<{ mcpServer: McpServer }>(
        "/api/settings/mcp_servers",
        server,
      );
      mcpServers.value.push(data.mcpServer);
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to add MCP server";
    } finally {
      loading.value = false;
    }
  }

  async function removeMcpServer(id: string) {
    loading.value = true;
    error.value = null;
    try {
      await api.delete(`/api/settings/mcp_servers/${id}`);
      mcpServers.value = mcpServers.value.filter((s) => s.id !== id);
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to remove MCP server";
    } finally {
      loading.value = false;
    }
  }

  return {
    modelConfig,
    mcpServers,
    loading,
    error,
    fetchModelConfig,
    saveModelConfig,
    fetchMcpServers,
    addMcpServer,
    removeMcpServer,
  };
});
