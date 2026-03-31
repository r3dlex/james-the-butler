<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">Plugins</h1>
      <button
        class="rounded px-3 py-1.5 text-sm font-medium"
        style="background: var(--color-gold); color: var(--color-navy-deep)"
        @click="showInstall = true"
      >
        Install Plugin
      </button>
    </div>

    <div v-if="showInstall" class="mb-4 rounded-md border p-4" style="border-color: var(--color-border)">
      <div class="flex items-end gap-3">
        <div class="flex-1">
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)">Plugin name</label>
          <input
            v-model="newName"
            type="text"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="border-color: var(--color-border); color: var(--color-text)"
            placeholder="my-plugin"
            @keydown.enter="installPlugin"
          />
        </div>
        <button
          class="rounded px-3 py-1.5 text-sm font-medium"
          style="background: var(--color-gold); color: var(--color-navy-deep)"
          @click="installPlugin"
        >
          Install
        </button>
        <button class="text-sm" style="color: var(--color-text-dim)" @click="showInstall = false; newName = ''">
          Cancel
        </button>
      </div>
    </div>

    <LoadingSpinner v-if="loading" />

    <EmptyState v-else-if="plugins.length === 0" message="No plugins installed." />

    <div v-else class="space-y-2">
      <div
        v-for="plugin in plugins"
        :key="plugin.id"
        class="flex items-center justify-between rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <div>
          <p class="text-sm font-medium" style="color: var(--color-text)">{{ plugin.name }}</p>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">v{{ plugin.version }}</p>
        </div>
        <div class="flex items-center gap-2">
          <button
            class="rounded px-2 py-0.5 text-xs"
            :style="{ background: plugin.enabled ? 'var(--color-gold)' : 'var(--color-surface)', color: plugin.enabled ? 'var(--color-navy-deep)' : 'var(--color-text-dim)' }"
            @click="togglePlugin(plugin)"
          >
            {{ plugin.enabled ? "Enabled" : "Disabled" }}
          </button>
          <button
            class="rounded p-1 text-xs transition-colors hover:bg-[var(--color-surface)]"
            style="color: var(--color-risk-red)"
            @click="uninstallPlugin(plugin)"
          >
            Uninstall
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

interface Plugin {
  id: string;
  name: string;
  version: string;
  enabled: boolean;
}

const plugins = ref<Plugin[]>([]);
const loading = ref(false);
const showInstall = ref(false);
const newName = ref("");

async function fetchPlugins() {
  loading.value = true;
  try {
    const data = await api.get<{ plugins: Plugin[] }>("/api/plugins");
    plugins.value = data.plugins;
  } catch {
    plugins.value = [];
  } finally {
    loading.value = false;
  }
}

async function installPlugin() {
  const name = newName.value.trim();
  if (!name) return;
  try {
    const data = await api.post<{ plugin: Plugin }>("/api/plugins", { name });
    plugins.value.push(data.plugin);
    newName.value = "";
    showInstall.value = false;
  } catch { /* */ }
}

async function togglePlugin(plugin: Plugin) {
  try {
    const action = plugin.enabled ? "disable" : "enable";
    const data = await api.post<{ plugin: Plugin }>(`/api/plugins/${plugin.id}/${action}`, {});
    const idx = plugins.value.findIndex((p) => p.id === plugin.id);
    if (idx !== -1) plugins.value[idx] = data.plugin;
  } catch { /* */ }
}

async function uninstallPlugin(plugin: Plugin) {
  try {
    await api.delete(`/api/plugins/${plugin.id}`);
    plugins.value = plugins.value.filter((p) => p.id !== plugin.id);
  } catch { /* */ }
}

onMounted(fetchPlugins);
</script>
