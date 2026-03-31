<template>
  <div class="mx-auto max-w-4xl p-6">
    <div class="mb-6 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">
        Sessions
      </h1>
      <button
        class="rounded-lg px-4 py-2 text-sm font-medium transition-opacity hover:opacity-90"
        style="background: var(--color-gold); color: var(--color-navy-deep)"
        @click="quickCreate"
      >
        New Session
      </button>
    </div>

    <LoadingSpinner v-if="sessionStore.loading" full-page />

    <EmptyState
      v-else-if="sessionStore.sessions.length === 0"
      message="No sessions yet. Create one to get started."
    />

    <div v-else class="space-y-2">
      <RouterLink
        v-for="session in sessionStore.sortedSessions"
        :key="session.id"
        :to="`/sessions/${session.id}`"
        class="flex items-center justify-between rounded-lg border p-4 transition-colors hover:bg-[var(--color-surface)]"
        style="border-color: var(--color-border)"
      >
        <div class="flex items-center gap-3">
          <div class="flex flex-col">
            <span class="text-sm font-medium" style="color: var(--color-text)">
              {{ session.name }}
            </span>
            <span
              class="text-xs capitalize"
              style="color: var(--color-text-dim)"
            >
              {{ agentTypeLabel(session.agentType) }}
            </span>
          </div>
        </div>
        <div class="flex items-center gap-3">
          <StatusBadge :status="session.status" />
          <span
            class="text-xs tabular-nums"
            style="color: var(--color-text-dim)"
          >
            {{ formatDate(session.updatedAt) }}
          </span>
        </div>
      </RouterLink>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from "vue";
import { useRouter } from "vue-router";
import { useSessionStore } from "@/stores/sessions";
import type { AgentType } from "@/types/session";
import StatusBadge from "@/components/common/StatusBadge.vue";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

const sessionStore = useSessionStore();
const router = useRouter();

onMounted(() => {
  sessionStore.fetchSessions();
});

async function quickCreate() {
  const session = await sessionStore.createSession({
    agentType: "chat",
    hostId: "primary",
  });
  if (session) {
    router.push(`/sessions/${session.id}`);
  }
}

const agentTypeLabels: Record<AgentType, string> = {
  chat: "Chat",
  code: "Code",
  research: "Research",
  desktop_control: "Desktop Control",
  browser_control: "Browser Control",
};

function agentTypeLabel(type: AgentType): string {
  return agentTypeLabels[type] ?? type;
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  const now = new Date();
  const diff = now.getTime() - d.getTime();
  if (diff < 60000) return "just now";
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
  return d.toLocaleDateString();
}
</script>
