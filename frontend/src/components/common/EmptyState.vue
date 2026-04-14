<template>
  <Card
    :pt="{
      root: {
        class:
          'flex flex-col items-center justify-center gap-3 py-16 border-0 shadow-none',
        style: 'background: transparent;',
      },
      content: { class: 'text-center' },
    }"
  >
    <template #content>
      <div class="text-4xl opacity-30">
        <slot name="icon">
          <span>--</span>
        </slot>
      </div>
      <p class="text-sm" style="color: var(--color-text-dim)">
        {{ message }}
      </p>
      <slot name="action" />
    </template>
  </Card>
</template>

<script setup lang="ts">
import Card from "primevue/card";

defineProps<{ message: string }>();
</script>
