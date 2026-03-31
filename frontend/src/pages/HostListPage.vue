<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">Hosts</h1>
    </div>

    <LoadingSpinner v-if="loading" />

    <EmptyState v-else-if="hosts.length === 0" message="No hosts registered. The primary host will appear here when configured." />

    <div v-else class="space-y-2">
      <router-link
        v-for="host in hosts"
        :key="host.id"
        :to="`/hosts/${host.id}`"
        class="block rounded-md border p-4 transition-colors hover:bg-[var(--color-surface)]"
        style="border-color: var(--color-border)"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <span
              class="inline-block h-2 w-2 rounded-full"
              :style="{ background: statusColor(host.status) }"
            />
            <div>
              <p class="text-sm font-medium" style="color: var(--color-text)">
                {{ host.name }}
                <span v-if="host.isPrimary" class="ml-1 text-xs" style="color: var(--color-gold)">(primary)</span>
              </p>
              <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
                {{ host.endpoint || "No endpoint" }}
              </p>
            </div>
          </div>
          <div class="text-right">
            <span class="text-xs capitalize" :style="{ color: statusColor(host.status) }">{{ host.status }}</span>
            <p v-if="host.lastSeenAt" class="mt-0.5 text-[10px]" style="color: var(--color-text-dim)">
              Last seen {{ formatRelative(host.lastSeenAt) }}
            </p>
          </div>
        </div>
      </router-link>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

interface Host {
  id: string;
  name: string;
  endpoint: string | null;
  status: string;
  isPrimary: boolean;
  lastSeenAt: string | null;
}

const hosts = ref<Host[]>([]);
const loading = ref(false);

function statusColor(status: string): string {
  switch (status) {
    case "online": return "var(--color-accent-blue)";
    case "draining": return "var(--color-gold)";
    default: return "var(--color-text-dim)";
  }
}

function formatRelative(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

async function fetchHosts() {
  loading.value = true;
  try {
    const data = await api.get<{ hosts: Host[] }>("/api/hosts");
    hosts.value = data.hosts;
  } catch {
    hosts.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(fetchHosts);
</script>
