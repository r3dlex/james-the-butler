<template>
  <div class="flex items-center justify-center" :class="containerClass">
    <div
      class="animate-spin rounded-full border-2 border-t-transparent"
      :class="sizeClass"
      style="
        border-color: var(--color-border);
        border-top-color: var(--color-gold);
      "
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";

const props = withDefaults(
  defineProps<{ size?: "sm" | "md" | "lg"; fullPage?: boolean }>(),
  { size: "md", fullPage: false },
);

const sizeClass = computed(() => {
  if (props.size === "sm") return "h-4 w-4";
  if (props.size === "lg") return "h-10 w-10";
  return "h-6 w-6";
});

const containerClass = computed(() => (props.fullPage ? "h-full" : ""));
</script>
