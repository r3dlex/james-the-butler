<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">Directories</h1>
      <button
        class="rounded px-3 py-1.5 text-sm font-medium"
        style="background: var(--color-gold); color: var(--color-navy-deep)"
        disabled
      >
        Add Directory
      </button>
    </div>
    <EmptyState message="No working directories configured. Directory management coming with the code agent." />
  </div>
</template>

<script setup lang="ts">
import EmptyState from "@/components/common/EmptyState.vue";
</script>
