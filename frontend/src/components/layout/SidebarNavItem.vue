<template>
  <RouterLink
    :to="path"
    class="flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors"
    :class="
      isActive ? 'bg-[var(--color-surface)]' : 'hover:bg-[var(--color-surface)]'
    "
    :style="{ color: isActive ? 'var(--color-gold)' : 'var(--color-text-dim)' }"
  >
    <component :is="iconComponent" class="h-4 w-4" />
    <span>{{ label }}</span>
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
} from "lucide-vue-next";

const props = defineProps<{
  label: string;
  path: string;
  icon: string;
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
};

const iconComponent = computed(() => iconMap[props.icon] ?? MessageSquare);
</script>
