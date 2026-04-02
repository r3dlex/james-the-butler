<template>
  <div
    class="border-t py-3"
    :class="collapsed ? 'px-1' : 'px-3'"
    style="border-color: var(--color-border)"
  >
    <div
      v-if="auth.user"
      class="flex items-center"
      :class="collapsed ? 'flex-col gap-1' : 'gap-2'"
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

      <!-- Logout button -->
      <button
        type="button"
        class="logout-btn shrink-0 rounded-md p-1.5 transition-colors"
        style="color: var(--color-text-dim)"
        :title="collapsed ? 'Logout' : undefined"
        @click="auth.logout()"
      >
        <!-- Log-out icon -->
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
          <polyline points="16 17 21 12 16 7" />
          <line x1="21" y1="12" x2="9" y2="12" />
        </svg>
      </button>
    </div>

    <!-- Unauthenticated fallback -->
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

<style scoped>
.logout-btn:hover {
  color: var(--color-risk-red) !important;
  background: rgba(248, 113, 113, 0.1);
}
</style>
