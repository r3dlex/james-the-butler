<template>
  <aside
    class="flex h-full flex-col border-r"
    style="background: var(--color-navy); border-color: var(--color-border)"
  >
    <!-- Brand header -->
    <div
      class="flex items-center gap-2.5 pt-4 pb-3"
      :class="collapsed ? 'justify-center px-0' : 'px-4'"
    >
      <img
        src="/logo-light.svg"
        alt="James the Butler"
        width="28"
        height="28"
        class="shrink-0"
      />
      <span
        v-if="!collapsed"
        class="truncate text-sm font-semibold tracking-tight"
        style="color: var(--color-gold); font-family: Georgia, serif"
      >
        James the Butler
      </span>
    </div>

    <div class="mx-3 h-px" style="background: var(--color-border)" />

    <!-- Main navigation -->
    <nav
      class="flex-1 overflow-y-auto py-2"
      :class="collapsed ? 'px-1' : 'space-y-0.5'"
    >
      <!-- Collapsed: icon-only nav items -->
      <template v-if="collapsed">
        <SidebarNavItem
          label="Sessions"
          path="/sessions"
          icon="message-square"
          :collapsed="collapsed"
        />
        <SidebarNavItem
          label="Projects"
          path="/projects"
          icon="folder"
          :collapsed="collapsed"
        />
        <SidebarNavItem
          label="Task List"
          path="/tasks"
          icon="list-checks"
          :collapsed="collapsed"
        />
        <SidebarNavItem
          label="Memory"
          path="/memory"
          icon="brain"
          :collapsed="collapsed"
        />
      </template>

      <!-- Expanded: rich sidebar sections -->
      <template v-else>
        <!-- Unified search -->
        <div class="relative mb-1 px-2">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            class="absolute left-4.5 top-1/2 -translate-y-1/2"
            style="color: var(--color-text-dim)"
          >
            <circle cx="11" cy="11" r="8" />
            <path d="m21 21-4.3-4.3" />
          </svg>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Search…"
            class="w-full rounded-md py-1 pl-7 pr-2 text-xs outline-none"
            style="
              background: var(--color-surface);
              color: var(--color-text);
              border: 1px solid var(--color-border);
            "
          />
        </div>
        <!-- Sessions section with search -->
        <SidebarSessionsSection :query="searchQuery" />
        <div class="mx-3 h-px my-1" style="background: var(--color-border)" />
        <!-- Projects section -->
        <SidebarProjectsSection :query="searchQuery" />
        <div class="mx-3 h-px my-1" style="background: var(--color-border)" />
        <!-- Other nav items -->
        <SidebarNavItem
          label="Task List"
          path="/tasks"
          icon="list-checks"
          :collapsed="collapsed"
        />
        <SidebarNavItem
          label="Memory"
          path="/memory"
          icon="brain"
          :collapsed="collapsed"
        />
      </template>
    </nav>

    <div class="mx-3 h-px" style="background: var(--color-border)" />

    <!-- Settings group -->
    <nav class="space-y-0.5 py-2" :class="collapsed ? 'px-1' : 'px-2'">
      <!-- Settings toggle row (expanded sidebar) -->
      <button
        v-if="!collapsed"
        type="button"
        class="flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
        :style="{
          color: isSettingsActive
            ? 'var(--color-gold)'
            : 'var(--color-text-dim)',
          background: isSettingsActive ? 'var(--color-surface)' : undefined,
        }"
        @click="toggleSettings"
      >
        <SettingsIcon class="h-4 w-4 shrink-0" />
        <span class="flex-1 text-left">Settings</span>
        <!-- Chevron -->
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class="transition-transform duration-150"
          :class="settingsOpen ? 'rotate-180' : ''"
        >
          <path d="m6 9 6 6 6-6" />
        </svg>
      </button>

      <!-- Settings icon-only (collapsed sidebar) -->
      <RouterLink
        v-else
        to="/settings"
        class="flex items-center justify-center rounded-md px-2 py-2 transition-colors hover:bg-[var(--color-surface)]"
        :style="{
          color: isSettingsActive
            ? 'var(--color-gold)'
            : 'var(--color-text-dim)',
        }"
        title="Settings"
      >
        <SettingsIcon class="h-4 w-4 shrink-0" />
      </RouterLink>

      <!-- Sub-items (expanded sidebar only, shown when settingsOpen) -->
      <template v-if="!collapsed && settingsOpen">
        <RouterLink
          v-for="item in settingsItems"
          :key="item.path"
          :to="item.path"
          class="ml-3 flex items-center gap-2 rounded-md px-3 py-1.5 text-sm transition-colors hover:bg-[var(--color-surface)]"
          :style="{
            color: isItemActive(item.path)
              ? 'var(--color-gold)'
              : 'var(--color-text-dim)',
            background: isItemActive(item.path)
              ? 'var(--color-surface)'
              : undefined,
          }"
        >
          <component :is="item.iconComponent" class="h-3.5 w-3.5 shrink-0" />
          <span>{{ item.label }}</span>
        </RouterLink>
      </template>
    </nav>

    <div class="mx-3 h-px" style="background: var(--color-border)" />

    <!-- Footer -->
    <SidebarFooter :collapsed="collapsed" />
  </aside>
</template>

<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { useRoute, RouterLink } from "vue-router";
import SidebarNavItem from "./SidebarNavItem.vue";
import SidebarFooter from "./SidebarFooter.vue";
import SidebarSessionsSection from "./SidebarSessionsSection.vue";
import SidebarProjectsSection from "./SidebarProjectsSection.vue";
import {
  Settings as SettingsIcon,
  Sliders,
  Cpu,
  Server,
  Activity,
  Puzzle,
  Zap,
  Radio,
  Smartphone,
  Plug,
  Shield,
  Monitor,
} from "lucide-vue-next";

defineProps<{
  collapsed?: boolean;
}>();

const route = useRoute();
const searchQuery = ref("");

// ── Settings items ────────────────────────────────────────────────────────────
const settingsItems = [
  { label: "General", path: "/settings/general", iconComponent: Sliders },
  { label: "Providers", path: "/settings/models", iconComponent: Cpu },
  { label: "Hosts", path: "/hosts", iconComponent: Server },
  { label: "OpenClaw", path: "/openclaw", iconComponent: Activity },
  { label: "MCP Servers", path: "/settings/mcp", iconComponent: Plug },
  { label: "Plugins", path: "/settings/plugins", iconComponent: Puzzle },
  { label: "Hooks", path: "/settings/hooks", iconComponent: Zap },
  { label: "Channels", path: "/settings/channels", iconComponent: Radio },
  {
    label: "Mobile Setup",
    path: "/mobile-setup",
    iconComponent: Smartphone,
  },
  { label: "Security", path: "/settings/security", iconComponent: Shield },
  {
    label: "Desktop Control",
    path: "/settings/desktop-control",
    iconComponent: Monitor,
  },
];

const SETTINGS_PATHS = ["/settings", "/hosts", "/openclaw", "/mobile-setup"];

function isItemActive(path: string): boolean {
  return route.path === path || route.path.startsWith(path + "/");
}

const isSettingsActive = computed(() =>
  SETTINGS_PATHS.some(
    (p) => route.path === p || route.path.startsWith(p + "/"),
  ),
);

// ── Collapsible settings group ────────────────────────────────────────────────
const SETTINGS_OPEN_KEY = "james_settings_open";
const settingsOpen = ref(
  localStorage.getItem(SETTINGS_OPEN_KEY) !== "false" &&
    (isSettingsActive.value ||
      localStorage.getItem(SETTINGS_OPEN_KEY) === "true"),
);

watch(settingsOpen, (v) => localStorage.setItem(SETTINGS_OPEN_KEY, String(v)));

// Auto-open group when navigating to a settings route
watch(
  isSettingsActive,
  (active) => {
    if (active) settingsOpen.value = true;
  },
  { immediate: true },
);

function toggleSettings() {
  settingsOpen.value = !settingsOpen.value;
}
</script>
