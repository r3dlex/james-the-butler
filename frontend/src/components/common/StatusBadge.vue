<template>
  <Tag
    :value="label"
    :severity="tagSeverity"
    :pt="{
      root: {
        class:
          'inline-flex items-center gap-1.5 text-xs px-2 py-0.5 rounded-full font-medium',
      },
    }"
  />
</template>

<script setup lang="ts">
import { computed } from "vue";
import Tag from "primevue/tag";

const props = defineProps<{ status: string }>();

const statusColors: Record<string, string> = {
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
  () => statusColors[props.status] ?? "var(--color-text-dim)",
);
const label = computed(
  () => props.status.charAt(0).toUpperCase() + props.status.slice(1),
);

const tagSeverity = computed(() => {
  const color = dotColor.value;
  if (color === "var(--color-risk-green)") return "success" as const;
  if (color === "var(--color-gold)") return "warn" as const;
  if (color === "var(--color-risk-red)") return "danger" as const;
  if (color === "var(--color-accent-blue)") return "secondary" as const;
  return "secondary" as const;
});
</script>
