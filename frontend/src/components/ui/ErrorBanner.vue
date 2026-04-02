<template>
  <Transition
    enter-active-class="transition-all duration-200 ease-out"
    enter-from-class="opacity-0 -translate-y-1"
    enter-to-class="opacity-100 translate-y-0"
    leave-active-class="transition-all duration-150 ease-in"
    leave-from-class="opacity-100 translate-y-0"
    leave-to-class="opacity-0 -translate-y-1"
  >
    <div
      v-if="message"
      role="alert"
      class="flex items-start gap-2 rounded-lg border px-4 py-3 text-sm"
      style="
        border-color: var(--color-risk-red);
        background: rgba(239, 68, 68, 0.08);
        color: var(--color-risk-red);
      "
    >
      <!-- Warning icon -->
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="16"
        height="16"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
        class="mt-0.5 shrink-0"
      >
        <circle cx="12" cy="12" r="10" />
        <line x1="12" y1="8" x2="12" y2="12" />
        <line x1="12" y1="16" x2="12.01" y2="16" />
      </svg>

      <span class="flex-1">{{ message }}</span>

      <!-- Optional dismiss button -->
      <button
        v-if="dismissible"
        type="button"
        class="shrink-0 opacity-70 transition-opacity hover:opacity-100"
        aria-label="Dismiss"
        @click="$emit('dismiss')"
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
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>
  </Transition>
</template>

<script setup lang="ts">
defineProps<{
  message: string | null;
  dismissible?: boolean;
}>();

defineEmits<{
  dismiss: [];
}>();
</script>
