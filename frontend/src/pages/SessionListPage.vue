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
      <div
        v-for="session in sessionStore.sortedSessions"
        :key="session.id"
        class="group flex items-center justify-between rounded-lg border p-4 transition-colors hover:bg-[var(--color-surface)]"
        style="border-color: var(--color-border)"
      >
        <!-- Clickable area navigates to session -->
        <RouterLink
          :to="`/sessions/${session.id}`"
          class="flex min-w-0 flex-1 items-center gap-3"
        >
          <div class="flex min-w-0 flex-col">
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
        </RouterLink>

        <div class="flex items-center gap-3">
          <StatusBadge :status="session.status" />
          <span
            class="text-xs tabular-nums"
            style="color: var(--color-text-dim)"
          >
            {{ formatDate(session.updatedAt) }}
          </span>

          <!-- Delete button — visible on hover -->
          <button
            class="rounded-md px-2.5 py-1 text-xs font-medium opacity-0 transition-opacity group-hover:opacity-100"
            style="
              background: rgba(239, 68, 68, 0.12);
              color: var(--color-risk-red);
              border: 1px solid rgba(239, 68, 68, 0.3);
            "
            :title="`Delete session '${session.name}'`"
            @click.prevent="requestDelete(session.id, session.name)"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Delete confirmation dialog -->
    <ConfirmDialog
      :open="confirmOpen"
      title="Delete session?"
      :description="`'${confirmSessionName}' and all its messages will be permanently deleted from the database. This cannot be undone.`"
      confirm-label="Delete"
      cancel-label="Cancel"
      variant="danger"
      @confirm="confirmDelete"
      @cancel="cancelDelete"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useSessionStore } from "@/stores/sessions";
import type { AgentType } from "@/types/session";
import StatusBadge from "@/components/common/StatusBadge.vue";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";
import ConfirmDialog from "@/components/ui/ConfirmDialog.vue";

const sessionStore = useSessionStore();
const router = useRouter();

// ── Delete confirmation state ────────────────────────────────────────────────
const confirmOpen = ref(false);
const confirmSessionId = ref<string | null>(null);
const confirmSessionName = ref("");

function requestDelete(id: string, name: string) {
  confirmSessionId.value = id;
  confirmSessionName.value = name;
  confirmOpen.value = true;
}

async function confirmDelete() {
  if (!confirmSessionId.value) return;
  await sessionStore.deleteSession(confirmSessionId.value);
  confirmOpen.value = false;
  confirmSessionId.value = null;
}

function cancelDelete() {
  confirmOpen.value = false;
  confirmSessionId.value = null;
}

// ── Lifecycle ────────────────────────────────────────────────────────────────
onMounted(() => {
  sessionStore.fetchSessions();
});

// ── Actions ──────────────────────────────────────────────────────────────────
async function quickCreate() {
  const session = await sessionStore.createSession({
    agentType: "chat",
    hostId: "primary",
  });
  if (session) {
    router.push(`/sessions/${session.id}`);
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
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

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "—";
  const now = new Date();
  const diff = now.getTime() - d.getTime();
  if (diff < 0) return "just now"; // future timestamps (clock skew)
  if (diff < 60_000) return "just now";
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return d.toLocaleDateString();
}
</script>
