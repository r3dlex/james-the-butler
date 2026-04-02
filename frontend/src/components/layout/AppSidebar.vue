<template>
  <aside
    class="flex h-full flex-col border-r"
    style="background: var(--color-navy); border-color: var(--color-border)"
  >
    <!-- Brand header -->
    <div
      class="flex items-center gap-2.5 px-3 pt-4 pb-3"
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

    <!-- New session button -->
    <div class="px-2 pb-2" :class="collapsed ? 'px-1' : 'px-2'">
      <button
        class="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors hover:opacity-90"
        :class="collapsed ? 'justify-center px-2' : 'px-3'"
        style="background: var(--color-gold); color: var(--color-navy)"
        :title="collapsed ? 'New session' : undefined"
        @click="newSession"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          class="shrink-0"
        >
          <path d="M5 12h14" />
          <path d="M12 5v14" />
        </svg>
        <span v-if="!collapsed">New session</span>
      </button>
    </div>

    <div class="mx-3 h-px" style="background: var(--color-border)" />

    <!-- Main navigation -->
    <nav class="flex-1 space-y-0.5 overflow-y-auto py-2" :class="collapsed ? 'px-1' : 'px-2'">
      <SidebarNavItem label="Sessions" path="/sessions" icon="message-square" :collapsed="collapsed" />
      <SidebarNavItem label="Projects" path="/projects" icon="folder" :collapsed="collapsed" />
      <SidebarNavItem label="Task List" path="/tasks" icon="list-checks" :collapsed="collapsed" />
      <SidebarNavItem label="Memory" path="/memory" icon="brain" :collapsed="collapsed" />
      <SidebarNavItem label="Hosts" path="/hosts" icon="server" :collapsed="collapsed" />
      <SidebarNavItem label="OpenClaw" path="/openclaw" icon="activity" :collapsed="collapsed" />
    </nav>

    <div class="mx-3 h-px" style="background: var(--color-border)" />

    <!-- Bottom navigation -->
    <nav class="space-y-0.5 py-2" :class="collapsed ? 'px-1' : 'px-2'">
      <SidebarNavItem label="Settings" path="/settings" icon="settings" :collapsed="collapsed" />
      <SidebarNavItem label="Plugins" path="/settings/plugins" icon="puzzle" :collapsed="collapsed" />
      <SidebarNavItem label="Hooks" path="/settings/hooks" icon="zap" :collapsed="collapsed" />
      <SidebarNavItem label="Channels" path="/settings/channels" icon="radio" :collapsed="collapsed" />
      <SidebarNavItem label="Mobile Setup" path="/mobile-setup" icon="smartphone" :collapsed="collapsed" />
    </nav>

    <div class="mx-3 h-px" style="background: var(--color-border)" />

    <!-- Footer -->
    <SidebarFooter :collapsed="collapsed" />
  </aside>
</template>

<script setup lang="ts">
import { useRouter } from "vue-router";
import { useSessionStore } from "@/stores/sessions";
import SidebarNavItem from "./SidebarNavItem.vue";
import SidebarFooter from "./SidebarFooter.vue";

defineProps<{
  collapsed?: boolean;
}>();

const router = useRouter();
const sessionStore = useSessionStore();

async function newSession() {
  const session = await sessionStore.createSession({
    agentType: "chat",
    hostId: "primary",
  });
  if (session) {
    router.push(`/sessions/${session.id}`);
  }
}
</script>
