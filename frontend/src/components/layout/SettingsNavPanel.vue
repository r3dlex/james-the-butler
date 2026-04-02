<template>
  <!-- Secondary settings nav shown in main content area when sidebar is collapsed -->
  <div
    class="flex h-full flex-shrink-0 flex-col border-r"
    style="
      width: 200px;
      background: var(--color-navy);
      border-color: var(--color-border);
    "
  >
    <div class="px-4 pt-4 pb-2">
      <span
        class="text-xs font-semibold uppercase tracking-wider"
        style="color: var(--color-text-dim)"
      >
        Settings
      </span>
    </div>

    <nav class="flex-1 space-y-0.5 overflow-y-auto px-2 py-1">
      <RouterLink
        v-for="item in settingsItems"
        :key="item.path"
        :to="item.path"
        class="flex items-center gap-2.5 rounded-md px-3 py-2 text-sm transition-colors"
        :class="
          isActive(item.path)
            ? 'bg-[var(--color-surface)]'
            : 'hover:bg-[var(--color-surface)]'
        "
        :style="{
          color: isActive(item.path)
            ? 'var(--color-gold)'
            : 'var(--color-text-dim)',
        }"
      >
        <component :is="item.iconComponent" class="h-4 w-4 shrink-0" />
        <span>{{ item.label }}</span>
      </RouterLink>
    </nav>
  </div>
</template>

<script setup lang="ts">
import { useRoute } from "vue-router";
import {
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

const route = useRoute();

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

function isActive(path: string): boolean {
  return route.path === path || route.path.startsWith(path + "/");
}
</script>
