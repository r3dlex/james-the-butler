<template>
  <div class="flex h-screen overflow-hidden bg-[var(--color-navy-deep)]">
    <AppSidebar />
    <div class="flex flex-1 flex-col overflow-hidden">
      <AppHeader @search="showSearch = true" />
      <main class="flex-1 overflow-auto">
        <slot />
      </main>
    </div>
    <SearchOverlay :visible="showSearch" @close="showSearch = false" />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from "vue";
import AppSidebar from "./AppSidebar.vue";
import AppHeader from "./AppHeader.vue";
import SearchOverlay from "./SearchOverlay.vue";

const showSearch = ref(false);

function handleKeydown(e: KeyboardEvent) {
  // Open search with "/" key (unless in an input)
  if (
    e.key === "/" &&
    !["INPUT", "TEXTAREA"].includes((e.target as HTMLElement)?.tagName)
  ) {
    e.preventDefault();
    showSearch.value = true;
  }
}

onMounted(() => document.addEventListener("keydown", handleKeydown));
onUnmounted(() => document.removeEventListener("keydown", handleKeydown));
</script>
