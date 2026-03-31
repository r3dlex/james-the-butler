<template>
  <div class="border-t px-4 py-3" style="border-color: var(--color-border)">
    <div v-if="auth.user" class="flex items-center gap-2">
      <div
        class="flex h-7 w-7 items-center justify-center rounded-full text-xs font-medium"
        style="background: var(--color-surface); color: var(--color-gold)"
      >
        {{ initials }}
      </div>
      <div class="min-w-0 flex-1">
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
    <div v-else class="text-xs" style="color: var(--color-text-dim)">
      v0.1.0
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useAuthStore } from "@/stores/auth";

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
