<template>
  <div class="p-6">
    <LoadingSpinner v-if="loading" />

    <template v-else-if="host">
      <div class="mb-4">
        <div class="flex items-center gap-3">
          <span
            class="inline-block h-2.5 w-2.5 rounded-full"
            :style="{ background: statusColor(host.status) }"
          />
          <h1 class="text-lg font-medium" style="color: var(--color-text)">
            {{ host.name }}
            <span v-if="host.isPrimary" class="ml-1 text-xs" style="color: var(--color-gold)">(primary)</span>
          </h1>
        </div>
      </div>

      <div class="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div class="rounded-md border p-3" style="border-color: var(--color-border)">
          <p class="text-[10px] uppercase tracking-wider" style="color: var(--color-text-dim)">Status</p>
          <p class="mt-1 text-sm font-medium capitalize" :style="{ color: statusColor(host.status) }">{{ host.status }}</p>
        </div>
        <div class="rounded-md border p-3" style="border-color: var(--color-border)">
          <p class="text-[10px] uppercase tracking-wider" style="color: var(--color-text-dim)">Endpoint</p>
          <p class="mt-1 text-sm" style="color: var(--color-text)">{{ host.endpoint || "—" }}</p>
        </div>
        <div class="rounded-md border p-3" style="border-color: var(--color-border)">
          <p class="text-[10px] uppercase tracking-wider" style="color: var(--color-text-dim)">Sessions</p>
          <p class="mt-1 text-sm font-medium" style="color: var(--color-text)">{{ sessions.length }}</p>
        </div>
        <div class="rounded-md border p-3" style="border-color: var(--color-border)">
          <p class="text-[10px] uppercase tracking-wider" style="color: var(--color-text-dim)">Last Seen</p>
          <p class="mt-1 text-sm" style="color: var(--color-text)">{{ host.lastSeenAt ? formatRelative(host.lastSeenAt) : "—" }}</p>
        </div>
      </div>

      <h2 class="mb-2 text-sm font-medium" style="color: var(--color-text-dim)">Active Sessions</h2>

      <EmptyState v-if="sessions.length === 0" message="No active sessions on this host." />

      <div v-else class="space-y-2">
        <router-link
          v-for="session in sessions"
          :key="session.id"
          :to="`/sessions/${session.id}`"
          class="block rounded-md border p-3 transition-colors hover:bg-[var(--color-surface)]"
          style="border-color: var(--color-border)"
        >
          <p class="text-sm" style="color: var(--color-text)">{{ session.name }}</p>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">{{ session.agentType }} · {{ session.status }}</p>
        </router-link>
      </div>
    </template>

    <EmptyState v-else message="Host not found." />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useRoute } from "vue-router";
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

interface Session {
  id: string;
  name: string;
  agentType: string;
  status: string;
}

const route = useRoute();
const host = ref<Host | null>(null);
const sessions = ref<Session[]>([]);
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

async function fetchHost() {
  loading.value = true;
  try {
    const data = await api.get<{ host: Host; sessions: Session[] }>(`/api/hosts/${route.params.id}`);
    host.value = data.host;
    sessions.value = data.sessions || [];
  } catch {
    host.value = null;
  } finally {
    loading.value = false;
  }
}

onMounted(fetchHost);
</script>
