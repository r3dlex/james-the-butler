<template>
  <aside
    class="flex w-64 flex-col border-r"
    style="background: var(--color-navy); border-color: var(--color-border)"
  >
    <!-- Top actions -->
    <div class="space-y-0.5 px-2 pt-3 pb-2">
      <button
        class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
        style="color: var(--color-text)"
        @click="newSession"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          style="color: var(--color-text-dim)"
        >
          <path d="M5 12h14" />
          <path d="M12 5v14" />
        </svg>
        New session
      </button>

      <button
        class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
        style="color: var(--color-text)"
        @click="router.push('/tasks')"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          style="color: var(--color-text-dim)"
        >
          <circle cx="11" cy="11" r="8" />
          <path d="m21 21-4.3-4.3" />
        </svg>
        Search
      </button>

      <button
        class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
        style="color: var(--color-text)"
        @click="router.push('/hosts')"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          style="color: var(--color-text-dim)"
        >
          <rect width="18" height="18" x="3" y="3" rx="2" />
          <path d="M3 9h18" />
          <path d="M9 21V9" />
        </svg>
        Dispatch
      </button>

      <button
        class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
        style="color: var(--color-text)"
        @click="router.push('/settings')"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          style="color: var(--color-text-dim)"
        >
          <path
            d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"
          />
          <circle cx="12" cy="12" r="3" />
        </svg>
        Customize
      </button>
    </div>

    <div class="my-1 mx-3 h-px" style="background: var(--color-border)" />

    <!-- Project filter -->
    <div class="flex items-center justify-between px-3 py-2">
      <button
        class="flex items-center gap-1 rounded-md border px-2 py-1 text-xs transition-colors hover:bg-[var(--color-surface)]"
        style="
          border-color: var(--color-accent-blue);
          color: var(--color-text);
        "
      >
        All projects
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="m6 9 6 6 6-6" />
        </svg>
      </button>
      <button
        class="rounded p-1 transition-colors hover:bg-[var(--color-surface)]"
        style="color: var(--color-text-dim)"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <line x1="4" x2="4" y1="21" y2="14" />
          <line x1="4" x2="4" y1="10" y2="3" />
          <line x1="12" x2="12" y1="21" y2="12" />
          <line x1="12" x2="12" y1="8" y2="3" />
          <line x1="20" x2="20" y1="21" y2="16" />
          <line x1="20" x2="20" y1="12" y2="3" />
          <line x1="2" x2="6" y1="14" y2="14" />
          <line x1="10" x2="14" y1="8" y2="8" />
          <line x1="18" x2="22" y1="16" y2="16" />
        </svg>
      </button>
    </div>

    <!-- Session list grouped by date -->
    <div class="flex-1 overflow-y-auto px-2">
      <div
        v-for="group in groupedSessions"
        :key="group.label"
        class="mb-3"
      >
        <div
          class="px-2 pb-1 text-xs font-medium"
          style="color: var(--color-text-dim)"
        >
          {{ group.label }}
        </div>
        <RouterLink
          v-for="session in group.sessions"
          :key="session.id"
          :to="`/sessions/${session.id}`"
          class="flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm transition-colors hover:bg-[var(--color-surface)]"
          :class="
            activeSessionId === session.id
              ? 'bg-[var(--color-surface)]'
              : ''
          "
          :style="{
            color:
              activeSessionId === session.id
                ? 'var(--color-text)'
                : 'var(--color-text-dim)',
          }"
        >
          <!-- Session icon based on type -->
          <span
            class="flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs"
            :style="{
              background:
                session.status === 'active'
                  ? 'rgba(212, 165, 116, 0.15)'
                  : 'var(--color-surface)',
              color:
                session.status === 'active'
                  ? 'var(--color-gold)'
                  : 'var(--color-text-dim)',
            }"
          >
            {{ sessionIcon(session.agentType) }}
          </span>
          <span class="min-w-0 flex-1 truncate">
            {{ session.name }}
          </span>
        </RouterLink>
      </div>

      <div
        v-if="sessions.length === 0"
        class="px-3 py-4 text-center text-xs"
        style="color: var(--color-text-dim)"
      >
        <span class="italic">New session</span>
      </div>
    </div>

    <!-- Footer -->
    <SidebarFooter />
  </aside>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useRouter } from "vue-router";
import { useSessionStore } from "@/stores/sessions";
import type { AgentType, Session } from "@/types/session";
import SidebarFooter from "./SidebarFooter.vue";

const router = useRouter();
const sessionStore = useSessionStore();

const sessions = computed(() => sessionStore.sortedSessions);
const activeSessionId = computed(() => sessionStore.activeSessionId);

interface SessionGroup {
  label: string;
  sessions: Session[];
}

const groupedSessions = computed((): SessionGroup[] => {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today.getTime() - 86400000);
  const weekAgo = new Date(today.getTime() - 7 * 86400000);

  const groups: Record<string, Session[]> = {
    Today: [],
    Yesterday: [],
    "Previous 7 Days": [],
    Older: [],
  };

  for (const s of sessions.value) {
    const d = new Date(s.updatedAt);
    if (d >= today) groups["Today"].push(s);
    else if (d >= yesterday) groups["Yesterday"].push(s);
    else if (d >= weekAgo) groups["Previous 7 Days"].push(s);
    else groups["Older"].push(s);
  }

  return Object.entries(groups)
    .filter(([, list]) => list.length > 0)
    .map(([label, list]) => ({ label, sessions: list }));
});

function sessionIcon(type: AgentType): string {
  switch (type) {
    case "chat":
      return "\u{1F4AC}";
    case "code":
      return "\u{1F4BB}";
    case "research":
      return "\u{1F50D}";
    case "desktop_control":
      return "\u{1F5A5}";
    case "browser_control":
      return "\u{1F310}";
    default:
      return "\u{25CB}";
  }
}

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
