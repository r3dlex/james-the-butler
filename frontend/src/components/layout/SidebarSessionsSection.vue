<template>
  <div class="px-2 py-1">
    <!-- Search input -->
    <div class="relative mb-1">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        class="absolute left-2.5 top-1/2 -translate-y-1/2"
        style="color: var(--color-text-dim)"
      >
        <circle cx="11" cy="11" r="8" />
        <path d="m21 21-4.3-4.3" />
      </svg>
      <input
        v-model="query"
        type="text"
        placeholder="Search sessions…"
        class="w-full rounded-md py-1 pl-7 pr-2 text-xs outline-none"
        style="
          background: var(--color-surface);
          color: var(--color-text);
          border: 1px solid var(--color-border);
        "
        @input="onInput"
      />
    </div>

    <!-- Session list -->
    <div class="space-y-0.5">
      <RouterLink
        v-for="session in displayedSessions"
        :key="session.id"
        :to="`/sessions/${session.id}`"
        class="flex items-center gap-1.5 rounded-md px-2 py-1 text-sm transition-colors hover:bg-[var(--color-surface)]"
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
        <span class="truncate">{{ session.name }}</span>
      </RouterLink>

      <!-- Empty search state -->
      <p
        v-if="query && !displayedSessions.length"
        class="px-2 py-1 text-xs"
        style="color: var(--color-text-dim)"
      >
        No sessions match "{{ query }}"
      </p>
    </div>

    <!-- New Session button -->
    <button
      type="button"
      class="new-session-btn mt-1 flex w-full items-center gap-1.5 rounded-md px-2 py-1 text-xs transition-colors"
      style="color: var(--color-text-dim)"
      @click="newSession"
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
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { useRoute, useRouter, RouterLink } from "vue-router";
import { useSessionStore } from "@/stores/sessions";

const route = useRoute();
const router = useRouter();
const sessionStore = useSessionStore();

const query = ref("");

function onInput() {
  // reactive — handled by computed below
}

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
  const q = query.value.trim().toLowerCase();
  if (!q) return recentSessions.value;
  return sessionStore.sessions.filter((s) => s.name.toLowerCase().includes(q));
});

async function newSession() {
  const session = await sessionStore.createSession({
    agentType: "chat",
    hostId: "primary",
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
