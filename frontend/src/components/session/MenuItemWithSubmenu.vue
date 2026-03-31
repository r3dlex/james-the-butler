<template>
  <div class="relative" @mouseenter="open = true" @mouseleave="open = false">
    <button
      class="flex w-full items-center justify-between px-4 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
      style="color: var(--color-text)"
    >
      <span class="flex items-center gap-3">
        <svg
          v-if="icon === 'skills'"
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path
            d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H19a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H6.5a1 1 0 0 1 0-5H20"
          />
        </svg>
        <svg
          v-else-if="icon === 'connectors'"
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <rect x="2" y="6" width="6" height="6" rx="1" />
          <rect x="16" y="6" width="6" height="6" rx="1" />
          <rect x="9" y="2" width="6" height="6" rx="1" />
          <rect x="9" y="16" width="6" height="6" rx="1" />
          <path d="M12 8v8" />
          <path d="M8 9h2" />
          <path d="M14 9h2" />
        </svg>
        <svg
          v-else-if="icon === 'style'"
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path
            d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"
          />
        </svg>
        {{ label }}
      </span>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="14"
        height="14"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        style="color: var(--color-text-dim)"
      >
        <path d="m9 18 6-6-6-6" />
      </svg>
    </button>

    <!-- Submenu -->
    <div
      v-if="open"
      class="absolute bottom-0 left-full z-50 ml-1 w-52 rounded-xl border py-2 shadow-xl"
      style="
        background: var(--color-navy);
        border-color: var(--color-border);
      "
    >
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";

defineProps<{
  label: string;
  icon: "skills" | "connectors" | "style";
}>();

const open = ref(false);
</script>
