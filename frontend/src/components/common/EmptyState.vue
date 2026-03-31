<template>
  <div class="flex flex-col items-center justify-center gap-3 py-16">
    <div class="text-4xl opacity-30">
      <slot name="icon">
        <span>--</span>
      </slot>
    </div>
    <p class="text-sm" style="color: var(--color-text-dim)">
      {{ message }}
    </p>
    <slot name="action" />
  </div>
</template>

<script setup lang="ts">
defineProps<{ message: string }>();
</script>
