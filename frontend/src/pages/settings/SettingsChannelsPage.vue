<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">
        Channels
      </h1>
      <button
        class="rounded px-3 py-1.5 text-sm font-medium"
        style="background: var(--color-gold); color: var(--color-navy-deep)"
        @click="showCreate = true"
      >
        Add Channel
      </button>
    </div>

    <div
      v-if="showCreate"
      class="mb-4 rounded-md border p-4 space-y-3"
      style="border-color: var(--color-border)"
    >
      <div>
        <label class="mb-1 block text-xs" style="color: var(--color-text-dim)"
          >MCP Server Name</label
        >
        <input
          v-model="newServer"
          type="text"
          class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none"
          style="border-color: var(--color-border); color: var(--color-text)"
          placeholder="telegram-bot"
        />
      </div>
      <div class="flex gap-2">
        <button
          class="rounded px-3 py-1.5 text-sm font-medium"
          style="background: var(--color-gold); color: var(--color-navy-deep)"
          @click="createChannel"
        >
          Create
        </button>
        <button
          class="text-sm"
          style="color: var(--color-text-dim)"
          @click="showCreate = false"
        >
          Cancel
        </button>
      </div>
    </div>

    <LoadingSpinner v-if="loading" />

    <EmptyState
      v-else-if="channels.length === 0"
      message="No channels configured. Channels route external events (from MCP servers) into sessions."
    />

    <div v-else class="space-y-2">
      <div
        v-for="ch in channels"
        :key="ch.id"
        class="flex items-center justify-between rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <div>
          <p class="text-sm font-medium" style="color: var(--color-text)">
            {{ ch.mcpServer }}
          </p>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
            {{
              ch.sessionId
                ? `Session: ${ch.sessionId.slice(0, 8)}...`
                : "No session bound"
            }}
          </p>
        </div>
        <button
          class="text-xs"
          style="color: var(--color-risk-red)"
          @click="deleteChannel(ch)"
        >
          Delete
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

interface ChannelConfig {
  id: string;
  mcpServer: string;
  sessionId: string | null;
}

const channels = ref<ChannelConfig[]>([]);
const loading = ref(false);
const showCreate = ref(false);
const newServer = ref("");

async function fetchChannels() {
  loading.value = true;
  try {
    const data = await api.get<{ channelConfigs: ChannelConfig[] }>(
      "/api/channel-configs",
    );
    channels.value = data.channelConfigs || [];
  } catch {
    channels.value = [];
  } finally {
    loading.value = false;
  }
}

async function createChannel() {
  const server = newServer.value.trim();
  if (!server) return;
  try {
    const data = await api.post<{ channelConfig: ChannelConfig }>(
      "/api/channel-configs",
      { mcp_server: server },
    );
    channels.value.push(data.channelConfig);
    newServer.value = "";
    showCreate.value = false;
  } catch {
    /* */
  }
}

async function deleteChannel(ch: ChannelConfig) {
  try {
    await api.delete(`/api/channel-configs/${ch.id}`);
    channels.value = channels.value.filter((c) => c.id !== ch.id);
  } catch {
    /* */
  }
}

onMounted(fetchChannels);
</script>
