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
        <!-- Host name -->
        <div>
          <span style="color: var(--color-text-dim)">Host:</span>
          <span class="ml-1" style="color: var(--color-text)">
            {{ session.hostId }}
          </span>
        </div>
        <!-- Project link -->
        <div v-if="session.projectId">
          <span style="color: var(--color-text-dim)">Project:</span>
          <RouterLink
            :to="`/projects/${session.projectId}`"
            class="ml-1 underline"
            style="color: var(--color-accent-blue)"
          >
            {{ session.projectId }}
          </RouterLink>
        </div>
      </div>
    </div>

    <!-- Execution mode toggle -->
    <div v-if="session">
      <h3
        class="mb-2 text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Execution Mode
      </h3>
      <button
        data-testid="execution-mode-toggle"
        class="flex w-full items-center justify-between rounded-md px-3 py-1.5 text-xs font-medium transition-colors"
        :style="
          session.executionMode === 'confirmed'
            ? {
                background: 'var(--color-gold)',
                color: 'var(--color-navy-deep)',
              }
            : {
                background: 'var(--color-surface)',
                color: 'var(--color-text)',
              }
        "
        @click="toggleExecutionMode"
      >
        <span class="capitalize">{{ session.executionMode }}</span>
        <span class="text-[10px] opacity-60">
          {{
            session.executionMode === "confirmed"
              ? "asks first"
              : "runs directly"
          }}
        </span>
      </button>
    </div>

    <!-- Keep Intermediates toggle -->
    <div v-if="session">
      <h3
        class="mb-2 text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Keep Intermediates
      </h3>
      <button
        data-testid="keep-intermediates-toggle"
        class="flex w-full items-center justify-between rounded-md px-3 py-1.5 text-xs font-medium transition-colors"
        :style="
          session.keepIntermediates
            ? {
                background: 'var(--color-accent-blue)',
                color: 'white',
              }
            : {
                background: 'var(--color-surface)',
                color: 'var(--color-text)',
              }
        "
        @click="toggleKeepIntermediates"
      >
        <span>{{ session.keepIntermediates ? "On" : "Off" }}</span>
      </button>
    </div>

    <!-- Personality selector -->
    <div v-if="session">
      <h3
        class="mb-2 text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Personality
      </h3>
      <select
        data-testid="personality-selector"
        class="w-full rounded-md border px-2 py-1.5 text-xs"
        style="
          border-color: var(--color-border);
          background: var(--color-surface);
          color: var(--color-text);
        "
        :value="session.personalityId ?? ''"
        @change="onPersonalityChange"
      >
        <option value="">None</option>
        <option
          v-for="profile in personalityStore.profiles"
          :key="profile.id"
          :value="profile.id"
        >
          {{ profile.name }}
        </option>
      </select>
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
import type { Session, ExecutionMode } from "@/types/session";
import { useTokenStore } from "@/stores/tokens";
import { usePersonalityStore } from "@/stores/personality";
import { computed } from "vue";
import { RouterLink } from "vue-router";
import TokenDisplay from "@/components/common/TokenDisplay.vue";

const props = defineProps<{ session: Session | null }>();

const emit = defineEmits<{
  "update:executionMode": [mode: ExecutionMode];
  "update:keepIntermediates": [value: boolean];
  "update:personalityId": [id: string | null];
}>();

const tokenStore = useTokenStore();
const personalityStore = usePersonalityStore();

const tokenUsage = computed(() =>
  props.session ? tokenStore.getUsage(props.session.id) : null,
);

function toggleExecutionMode() {
  if (!props.session) return;
  const next: ExecutionMode =
    props.session.executionMode === "direct" ? "confirmed" : "direct";
  emit("update:executionMode", next);
}

function toggleKeepIntermediates() {
  if (!props.session) return;
  emit("update:keepIntermediates", !props.session.keepIntermediates);
}

function onPersonalityChange(event: Event) {
  const val = (event.target as HTMLSelectElement).value;
  emit("update:personalityId", val || null);
}
</script>
