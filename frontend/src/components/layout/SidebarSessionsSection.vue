<template>
  <div class="px-2 py-1">
    <!-- Section header -->
    <div class="mb-1 flex items-center justify-between px-1">
      <span
        class="text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Sessions
      </span>
      <RouterLink
        to="/sessions"
        class="text-xs transition-colors hover:text-[var(--color-gold)]"
        style="color: var(--color-text-dim)"
      >
        More →
      </RouterLink>
    </div>

    <!-- Session list -->
    <div class="space-y-0.5">
      <RouterLink
        v-for="session in displayedSessions"
        :key="session.id"
        :to="`/sessions/${session.id}`"
        class="flex min-w-0 items-center gap-1.5 rounded-md px-2 py-1 text-sm transition-colors hover:bg-[var(--color-surface)]"
        :style="{
          color:
            route.params.id === session.id
              ? 'var(--color-gold)'
              : 'var(--color-text)',
          background:
            route.params.id === session.id ? 'var(--color-surface)' : undefined,
        }"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="13"
          height="13"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class="shrink-0"
          style="color: var(--color-text-dim)"
        >
          <path
            d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"
          />
        </svg>
        <span class="min-w-0 truncate">{{ session.name }}</span>
      </RouterLink>

      <!-- Empty search state -->
      <p
        v-if="activeQuery && !displayedSessions.length"
        class="px-2 py-1 text-xs"
        style="color: var(--color-text-dim)"
      >
        No sessions match "{{ activeQuery }}"
      </p>
    </div>

    <!-- New Session button -->
    <button
      type="button"
      class="new-session-btn mt-1 flex w-full items-center gap-1.5 rounded-md px-2 py-1 text-xs transition-colors"
      style="color: var(--color-text-dim)"
      @click="showModal = true"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        class="shrink-0"
      >
        <path d="M5 12h14" />
        <path d="M12 5v14" />
      </svg>
      New Session
    </button>

    <!-- New session modal -->
    <NewSessionModal
      :open="showModal"
      @create="onCreateSession"
      @cancel="showModal = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { useRoute, useRouter, RouterLink } from "vue-router";
import { useSessionStore } from "@/stores/sessions";
import type { ExecutionMode } from "@/types/session";
import NewSessionModal from "@/components/session/NewSessionModal.vue";

const props = defineProps<{
  query?: string;
}>();

const route = useRoute();
const router = useRouter();
const sessionStore = useSessionStore();

const showModal = ref(false);

// Active query from parent (unified search in AppSidebar)
const activeQuery = computed(() => (props.query ?? "").trim().toLowerCase());

const recentSessions = computed(() =>
  [...sessionStore.sessions]
    .sort((a, b) => {
      const tA = new Date(a.updatedAt || a.createdAt || "").getTime() || 0;
      const tB = new Date(b.updatedAt || b.createdAt || "").getTime() || 0;
      return tB - tA;
    })
    .slice(0, 5),
);

const displayedSessions = computed(() => {
  const q = activeQuery.value;
  if (!q) return recentSessions.value;
  return sessionStore.sessions.filter((s) => s.name.toLowerCase().includes(q));
});

interface NewSessionPayload {
  name?: string;
  executionMode: ExecutionMode;
  workingDirectories: string[];
}

async function onCreateSession(payload: NewSessionPayload) {
  showModal.value = false;
  const session = await sessionStore.createSession({
    agentType: "chat",
    hostId: "primary",
    name: payload.name,
    executionMode: payload.executionMode,
    workingDirectories: payload.workingDirectories,
  });
  if (session) {
    router.push(`/sessions/${session.id}`);
  }
}
</script>

<style scoped>
.new-session-btn:hover {
  color: var(--color-gold) !important;
  background: var(--color-surface);
}
</style>
