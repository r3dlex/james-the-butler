<template>
  <Message
    :severity="severity"
    :closable="dismissible"
    :pt="{
      root: {
        class: 'rounded-lg border px-4 py-3 text-sm',
        style:
          'border-color: var(--color-risk-red); background: rgba(239, 68, 68, 0.08); color: var(--color-risk-red);',
      },
      content: { class: 'flex items-start gap-2' },
      icon: { class: 'mt-0.5 shrink-0' },
      wrapper: { class: 'flex items-start gap-2' },
    }"
    @close="$emit('dismiss')"
  >
    <template #icon>
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
      >
        <circle cx="12" cy="12" r="10" />
        <line x1="12" y1="8" x2="12" y2="12" />
        <line x1="12" y1="16" x2="12.01" y2="16" />
      </svg>
    </template>
    {{ message }}
  </Message>
</template>

<script setup lang="ts">
import Message from "primevue/message";

defineProps<{
  message: string | null;
  dismissible?: boolean;
}>();

defineEmits<{
  dismiss: [];
}>();

// ErrorBanner is always severity="error" for alert semantics
const severity = "error";
</script>
