<template>
  <div
    class="border-t py-3"
    :class="collapsed ? 'px-1' : 'px-4'"
    style="border-color: var(--color-border)"
  >
    <div
      v-if="auth.user"
      class="flex items-center"
      :class="collapsed ? 'justify-center' : 'gap-2'"
      :title="collapsed ? `${auth.user.name} · ${auth.user.email}` : undefined"
    >
      <!-- Avatar -->
      <div
        class="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-medium"
        style="background: var(--color-surface); color: var(--color-gold)"
      >
        {{ initials }}
      </div>
      <!-- Name + email — hidden when collapsed -->
      <div v-if="!collapsed" class="min-w-0 flex-1">
        <div
          class="truncate text-xs font-medium"
          style="color: var(--color-text)"
        >
          {{ auth.user.name }}
        </div>
        <div class="truncate text-xs" style="color: var(--color-text-dim)">
          {{ auth.user.email }}
        </div>
      </div>
    </div>
    <div
      v-else
      class="text-xs"
      :class="collapsed ? 'text-center' : ''"
      style="color: var(--color-text-dim)"
    >
      {{ collapsed ? "·" : "v0.1.0" }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useAuthStore } from "@/stores/auth";

defineProps<{
  collapsed?: boolean;
}>();

const auth = useAuthStore();

const initials = computed(() => {
  if (!auth.user) return "?";
  return auth.user.name
    .split(" ")
    .map((w) => w[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
});
</script>
