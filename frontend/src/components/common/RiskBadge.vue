<template>
  <Tag
    :value="label"
    :severity="tagSeverity"
    :pt="{
      root: {
        class:
          'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
      },
    }"
  />
</template>

<script setup lang="ts">
import { computed } from "vue";
import Tag from "primevue/tag";
import type { RiskLevel } from "@/types/task";

const props = defineProps<{ level: RiskLevel }>();

const config: Record<
  RiskLevel,
  { label: string; severity: "success" | "warn" | "danger" }
> = {
  read_only: {
    label: "Read Only",
    severity: "success",
  },
  additive: {
    label: "Additive",
    severity: "warn",
  },
  destructive: {
    label: "Destructive",
    severity: "danger",
  },
};

const tagSeverity = computed(() => config[props.level].severity);
const label = computed(() => config[props.level].label);
</script>
