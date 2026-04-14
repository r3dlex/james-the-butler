<template>
  <div class="flex items-center justify-center" :class="containerClass">
    <ProgressSpinner
      :pt="{
        root: {
          class: sizeClass,
          style:
            'border-color: var(--color-border); border-top-color: var(--color-gold);',
        },
      }"
    />
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import ProgressSpinner from "primevue/progressspinner";

const props = withDefaults(
  defineProps<{ size?: "sm" | "md" | "lg"; fullPage?: boolean }>(),
  { size: "md", fullPage: false },
);

const sizeClass = computed(() => {
  if (props.size === "sm") return "h-4 w-4 border-2";
  if (props.size === "lg") return "h-10 w-10 border-[3px]";
  return "h-6 w-6 border-2";
});

const containerClass = computed(() => (props.fullPage ? "h-full" : ""));
</script>
