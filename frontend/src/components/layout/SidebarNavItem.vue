<template>
  <RouterLink
    :to="path"
    class="flex items-center rounded-md py-2 text-sm transition-colors"
    :class="[
      isActive
        ? 'bg-[var(--color-surface)]'
        : 'hover:bg-[var(--color-surface)]',
      collapsed ? 'justify-center px-2' : 'gap-2 px-3',
    ]"
    :style="{ color: isActive ? 'var(--color-gold)' : 'var(--color-text-dim)' }"
    :title="collapsed ? label : undefined"
  >
    <component :is="iconComponent" class="h-4 w-4 shrink-0" />
    <span v-if="!collapsed">{{ label }}</span>
  </RouterLink>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useRoute } from "vue-router";
import {
  MessageSquare,
  Folder,
  ListChecks,
  Brain,
  Server,
  Activity,
  Settings,
  Smartphone,
  Puzzle,
  Zap,
  Radio,
  Cpu,
  Sliders,
  Plug,
  Home,
} from "lucide-vue-next";

const props = defineProps<{
  label: string;
  path: string;
  icon: string;
  collapsed?: boolean;
}>();

const route = useRoute();
const isActive = computed(() => route.path.startsWith(props.path));

const iconMap: Record<string, unknown> = {
  "message-square": MessageSquare,
  folder: Folder,
  "list-checks": ListChecks,
  brain: Brain,
  server: Server,
  activity: Activity,
  settings: Settings,
  smartphone: Smartphone,
  puzzle: Puzzle,
  zap: Zap,
  radio: Radio,
  cpu: Cpu,
  sliders: Sliders,
  plug: Plug,
  home: Home,
};

const iconComponent = computed(() => iconMap[props.icon] ?? MessageSquare);
</script>
