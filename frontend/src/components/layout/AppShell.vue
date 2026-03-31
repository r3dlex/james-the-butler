<template>
  <div class="flex h-screen overflow-hidden bg-[var(--color-navy-deep)]">
    <AppSidebar />
    <div class="flex flex-1 flex-col overflow-hidden">
      <AppHeader />
      <main class="flex-1 overflow-auto">
        <slot />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import AppSidebar from "./AppSidebar.vue";
import AppHeader from "./AppHeader.vue";
</script>
