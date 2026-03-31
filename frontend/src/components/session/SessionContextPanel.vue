<template>
  <aside
    class="flex w-60 flex-col gap-4 overflow-y-auto border-r p-4"
    style="border-color: var(--color-border)"
  >
    <div v-if="session">
      <h3
        class="mb-2 text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Session
      </h3>
      <div class="space-y-2 text-sm">
        <div>
          <span style="color: var(--color-text-dim)">Type:</span>
          <span class="ml-1 capitalize" style="color: var(--color-text)">
            {{ session.agentType.replace("_", " ") }}
          </span>
        </div>
        <div>
          <span style="color: var(--color-text-dim)">Mode:</span>
          <span class="ml-1 capitalize" style="color: var(--color-text)">
            {{ session.executionMode }}
          </span>
        </div>
        <div>
          <span style="color: var(--color-text-dim)">Host:</span>
          <span class="ml-1" style="color: var(--color-text)">
            {{ session.hostId }}
          </span>
        </div>
      </div>
    </div>

    <div v-if="session?.workingDirectories.length">
      <h3
        class="mb-2 text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Directories
      </h3>
      <div class="space-y-1">
        <div
          v-for="dir in session.workingDirectories"
          :key="dir"
          class="truncate rounded px-2 py-1 font-mono text-xs"
          style="background: var(--color-surface); color: var(--color-text-dim)"
        >
          {{ dir }}
        </div>
      </div>
    </div>

    <div v-if="session?.mcpServers.length">
      <h3
        class="mb-2 text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        MCP Servers
      </h3>
      <div class="space-y-1">
        <div
          v-for="mcp in session.mcpServers"
          :key="mcp"
          class="truncate rounded px-2 py-1 text-xs"
          style="background: var(--color-surface); color: var(--color-text-dim)"
        >
          {{ mcp }}
        </div>
      </div>
    </div>

    <div>
      <TokenDisplay
        :tokens="tokenUsage?.inputTokens ?? 0"
        :cost="tokenUsage?.cost ?? 0"
      />
    </div>
  </aside>
</template>

<script setup lang="ts">
import type { Session } from "@/types/session";
import { useTokenStore } from "@/stores/tokens";
import { computed } from "vue";
import TokenDisplay from "@/components/common/TokenDisplay.vue";

const props = defineProps<{ session: Session | null }>();

const tokenStore = useTokenStore();
const tokenUsage = computed(() =>
  props.session ? tokenStore.getUsage(props.session.id) : null,
);
</script>
