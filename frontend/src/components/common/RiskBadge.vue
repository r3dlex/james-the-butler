<template>
  <span
    class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium"
    :style="{ background: bgColor, color: textColor }"
  >
    {{ label }}
  </span>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { RiskLevel } from "@/types/task";

const props = defineProps<{ level: RiskLevel }>();

const config: Record<RiskLevel, { bg: string; text: string; label: string }> = {
  read_only: {
    bg: "rgba(74, 222, 128, 0.15)",
    text: "var(--color-risk-green)",
    label: "Read Only",
  },
  additive: {
    bg: "rgba(96, 165, 250, 0.15)",
    text: "var(--color-risk-blue)",
    label: "Additive",
  },
  destructive: {
    bg: "rgba(248, 113, 113, 0.15)",
    text: "var(--color-risk-red)",
    label: "Destructive",
  },
};

const bgColor = computed(() => config[props.level].bg);
const textColor = computed(() => config[props.level].text);
const label = computed(() => config[props.level].label);
</script>
