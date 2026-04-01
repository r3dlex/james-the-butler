<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">
        MCP Servers
      </h1>
      <button
        class="rounded px-3 py-1.5 text-sm font-medium"
        style="background: var(--color-gold); color: var(--color-navy-deep)"
        @click="showAddForm = !showAddForm"
      >
        Add Server
      </button>
    </div>

    <!-- Add server form -->
    <div
      v-if="showAddForm"
      class="mb-4 rounded-md border p-4"
      style="border-color: var(--color-border)"
    >
      <h2 class="mb-3 text-sm font-medium" style="color: var(--color-text)">
        New MCP Server
      </h2>
      <div class="space-y-3">
        <div>
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)"
            >Name</label
          >
          <input
            v-model="newServer.name"
            type="text"
            placeholder="My MCP Server"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="border-color: var(--color-border); color: var(--color-text)"
          />
        </div>
        <div>
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)"
            >Transport</label
          >
          <select
            v-model="newServer.transport"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="
              border-color: var(--color-border);
              color: var(--color-text);
              background: var(--color-navy-deep);
            "
          >
            <option value="stdio">stdio</option>
            <option value="sse">SSE</option>
            <option value="streamable_http">Streamable HTTP</option>
          </select>
        </div>
        <div class="flex gap-2">
          <button
            class="rounded px-3 py-1.5 text-sm font-medium"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
            @click="addServer"
          >
            Add
          </button>
          <button
            class="rounded border px-3 py-1.5 text-sm"
            style="border-color: var(--color-border); color: var(--color-text)"
            @click="showAddForm = false"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>

    <LoadingSpinner v-if="settingsStore.loading" />

    <EmptyState
      v-else-if="settingsStore.mcpServers.length === 0"
      message="No MCP servers configured."
    />

    <div v-else class="space-y-2">
      <div
        v-for="server in settingsStore.mcpServers"
        :key="server.id"
        class="flex items-center justify-between rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <div>
          <p class="text-sm font-medium" style="color: var(--color-text)">
            {{ server.name }}
          </p>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
            {{ server.transport }} · {{ server.status }}
          </p>
        </div>
        <button
          v-if="!server.isPreConfigured"
          class="rounded px-2 py-1 text-xs"
          style="color: var(--color-risk-red)"
          @click="settingsStore.removeMcpServer(server.id)"
        >
          Remove
        </button>
      </div>
    </div>

    <p
      v-if="settingsStore.error"
      class="mt-2 text-xs"
      style="color: var(--color-risk-red)"
    >
      {{ settingsStore.error }}
    </p>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useSettingsStore } from "@/stores/settings";
import type { McpTransport } from "@/types/mcp";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

const settingsStore = useSettingsStore();

const showAddForm = ref(false);
const newServer = ref<{ name: string; transport: McpTransport }>({
  name: "",
  transport: "stdio",
});

async function addServer() {
  if (!newServer.value.name.trim()) return;
  await settingsStore.addMcpServer({
    name: newServer.value.name.trim(),
    transport: newServer.value.transport,
    isPreConfigured: false,
    params: {},
  });
  if (!settingsStore.error) {
    newServer.value = { name: "", transport: "stdio" };
    showAddForm.value = false;
  }
}

onMounted(() => {
  settingsStore.fetchMcpServers();
});
</script>
