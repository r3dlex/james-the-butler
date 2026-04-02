<template>
  <div class="flex h-screen overflow-hidden bg-[var(--color-navy-deep)]">
    <!-- Sidebar — width transitions between expanded (w-64) and collapsed (w-14) -->
    <div
      class="relative flex-shrink-0 transition-all duration-200 ease-in-out"
      :class="sidebarCollapsed ? 'w-14' : 'w-64'"
    >
      <AppSidebar :collapsed="sidebarCollapsed" />

      <!-- Collapse / expand toggle button -->
      <button
        type="button"
        class="absolute -right-3 top-6 z-20 flex h-6 w-6 items-center justify-center rounded-full border shadow-sm transition-colors hover:bg-[var(--color-gold)]"
        style="
          background: var(--color-navy);
          border-color: var(--color-border);
          color: var(--color-text-dim);
        "
        :title="sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'"
        @click="toggleSidebar"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2.5"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path v-if="sidebarCollapsed" d="m9 18 6-6-6-6" />
          <path v-else d="m15 18-6-6 6-6" />
        </svg>
      </button>
    </div>

    <!-- Main content -->
    <div class="flex flex-1 flex-col overflow-hidden">
      <AppHeader @search="showSearch = true" />

      <!-- When sidebar is collapsed and we're on a settings route, show a
           secondary settings nav panel to the left of the page content.
           This fulfils the "dockable mode" requirement where settings sub-menus
           appear in the main area with a divider. -->
      <div class="flex flex-1 overflow-hidden">
        <SettingsNavPanel
          v-if="sidebarCollapsed && isSettingsRoute"
          class="flex-shrink-0"
        />

        <!-- Divider between settings panel and page content -->
        <div
          v-if="sidebarCollapsed && isSettingsRoute"
          class="h-full w-px flex-shrink-0"
          style="background: var(--color-border)"
        />

        <main class="flex-1 overflow-auto">
          <slot />
        </main>
      </div>
    </div>

    <SearchOverlay :visible="showSearch" @close="showSearch = false" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from "vue";
import { useRoute } from "vue-router";
import AppSidebar from "./AppSidebar.vue";
import AppHeader from "./AppHeader.vue";
import SearchOverlay from "./SearchOverlay.vue";
import SettingsNavPanel from "./SettingsNavPanel.vue";

const showSearch = ref(false);
const route = useRoute();

// ── Dockable sidebar ──────────────────────────────────────────────────────────
const STORAGE_KEY = "james_sidebar_collapsed";

const sidebarCollapsed = ref(localStorage.getItem(STORAGE_KEY) === "true");

watch(sidebarCollapsed, (v) => {
  localStorage.setItem(STORAGE_KEY, String(v));
});

function toggleSidebar() {
  sidebarCollapsed.value = !sidebarCollapsed.value;
}

// ── Settings route detection ──────────────────────────────────────────────────
// These are all paths that belong to the "Settings" group.  When the sidebar
// is collapsed and the user is on one of these paths, the SettingsNavPanel is
// rendered in the main content area instead of inside the sidebar.
const SETTINGS_PATHS = ["/settings", "/hosts", "/openclaw", "/mobile-setup"];

const isSettingsRoute = computed(() =>
  SETTINGS_PATHS.some(
    (p) => route.path === p || route.path.startsWith(p + "/"),
  ),
);

// ── Global keyboard shortcuts ─────────────────────────────────────────────────
function handleKeydown(e: KeyboardEvent) {
  const tag = (e.target as HTMLElement)?.tagName;
  if (["INPUT", "TEXTAREA"].includes(tag)) return;

  // "/" → open search
  if (e.key === "/") {
    e.preventDefault();
    showSearch.value = true;
  }

  // Cmd/Ctrl + "[" → toggle sidebar
  if (e.key === "[" && (e.metaKey || e.ctrlKey)) {
    e.preventDefault();
    toggleSidebar();
  }
}

onMounted(() => document.addEventListener("keydown", handleKeydown));
onUnmounted(() => document.removeEventListener("keydown", handleKeydown));
</script>
