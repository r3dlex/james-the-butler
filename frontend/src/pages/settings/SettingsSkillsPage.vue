<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">Skills</h1>
    </div>
    <EmptyState message="No skills installed. The skill system is coming in a future update." />
  </div>
</template>

<script setup lang="ts">
import EmptyState from "@/components/common/EmptyState.vue";
</script>
