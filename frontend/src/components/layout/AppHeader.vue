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
      <span class="text-xs tabular-nums" style="color: var(--color-text-dim)">
        {{ connectionLabel }}
      </span>
    </div>
  </header>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import { useSocketStore } from "@/stores/socket";

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
