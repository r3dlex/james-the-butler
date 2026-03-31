<template>
  <span
    class="inline-flex items-center gap-1.5 text-xs"
    :style="{ color: dotColor }"
  >
    <span class="h-1.5 w-1.5 rounded-full" :style="{ background: dotColor }" />
    {{ label }}
  </span>
</template>

<script setup lang="ts">
import { computed } from "vue";

const props = defineProps<{ status: string }>();

const colors: Record<string, string> = {
  active: "var(--color-risk-green)",
  running: "var(--color-risk-green)",
  idle: "var(--color-gold)",
  pending: "var(--color-text-dim)",
  completed: "var(--color-accent-blue)",
  blocked: "var(--color-risk-red)",
  failed: "var(--color-risk-red)",
  error: "var(--color-risk-red)",
  online: "var(--color-risk-green)",
  offline: "var(--color-text-dim)",
  degraded: "var(--color-gold)",
  connected: "var(--color-risk-green)",
  disconnected: "var(--color-text-dim)",
};

const dotColor = computed(
  () => colors[props.status] ?? "var(--color-text-dim)",
);
const label = computed(
  () => props.status.charAt(0).toUpperCase() + props.status.slice(1),
);
</script>
