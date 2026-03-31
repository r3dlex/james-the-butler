<template>
  <header
    class="flex h-12 items-center justify-between border-b px-4"
    style="
      border-color: var(--color-border);
      background: var(--color-navy-deep);
    "
  >
    <div class="flex items-center gap-2">
      <h2 class="text-sm font-medium" style="color: var(--color-text-dim)">
        {{ pageTitle }}
      </h2>
    </div>
    <div class="flex items-center gap-3">
      <!-- Search button -->
      <button
        v-if="auth.isAuthenticated"
        class="flex items-center gap-1.5 rounded-md border px-2 py-1 text-xs transition-colors hover:bg-[var(--color-surface)]"
        style="border-color: var(--color-border); color: var(--color-text-dim)"
        @click="$emit('search')"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <circle cx="11" cy="11" r="8" />
          <line x1="21" y1="21" x2="16.65" y2="16.65" />
        </svg>
        Search
        <kbd
          class="ml-1 rounded border px-1 text-[10px]"
          style="border-color: var(--color-border)"
        >
          /
        </kbd>
      </button>
      <span class="text-xs tabular-nums" style="color: var(--color-text-dim)">
        {{ connectionLabel }}
      </span>
      <button
        v-if="auth.isAuthenticated"
        class="rounded-md px-2 py-1 text-xs transition-colors hover:bg-[var(--color-surface)]"
        style="color: var(--color-text-dim)"
        @click="auth.logout()"
      >
        Logout
      </button>
    </div>
  </header>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import { useAuthStore } from "@/stores/auth";
import { useSocketStore } from "@/stores/socket";

defineEmits<{ search: [] }>();

const auth = useAuthStore();
const socketStore = useSocketStore();
const route = useRoute();

const pageTitle = computed(() => {
  const path = route.path;
  if (path.startsWith("/sessions/")) return "Session";
  if (path === "/sessions") return "Sessions";
  if (path.startsWith("/projects")) return "Projects";
  if (path === "/tasks") return "Tasks";
  if (path === "/memory") return "Memory";
  if (path.startsWith("/hosts")) return "Hosts";
  if (path === "/openclaw") return "OpenClaw";
  if (path.startsWith("/settings")) return "Settings";
  return "James the Butler";
});

const connectionLabel = computed(() => {
  const s = socketStore.status;
  if (s === "connected") return "Connected";
  if (s === "connecting") return "Connecting...";
  if (s === "error") return "Connection error";
  return "Disconnected";
});
</script>
