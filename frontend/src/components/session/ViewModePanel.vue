<template>
  <aside
    class="flex w-72 flex-col overflow-y-auto border-l"
    style="border-color: var(--color-border)"
  >
    <!-- Tab switcher -->
    <div class="flex border-b" style="border-color: var(--color-border)">
      <button
        data-testid="tab-tasks"
        class="flex-1 px-3 py-2 text-xs font-semibold uppercase tracking-wide transition-colors"
        :style="
          activeTab === 'tasks'
            ? {
                borderBottom: '2px solid var(--color-gold)',
                color: 'var(--color-text)',
              }
            : { color: 'var(--color-text-dim)' }
        "
        @click="activeTab = 'tasks'"
      >
        Tasks
      </button>
      <button
        data-testid="tab-view"
        class="flex-1 px-3 py-2 text-xs font-semibold uppercase tracking-wide transition-colors"
        :style="
          activeTab === 'view'
            ? {
                borderBottom: '2px solid var(--color-gold)',
                color: 'var(--color-text)',
              }
            : { color: 'var(--color-text-dim)' }
        "
        @click="activeTab = 'view'"
      >
        View
      </button>
    </div>

    <!-- Task list tab -->
    <div v-if="activeTab === 'tasks'" class="flex-1 overflow-y-auto p-4">
      <div
        v-if="tasks.length === 0"
        class="text-xs"
        style="color: var(--color-text-dim)"
      >
        No tasks yet
      </div>

      <div v-else class="space-y-2">
        <!-- Active and pending tasks -->
        <div
          v-for="task in activeTasks"
          :key="task.id"
          class="rounded-md border p-2"
          style="border-color: var(--color-border)"
        >
          <div class="flex items-start justify-between gap-2">
            <span class="text-xs" style="color: var(--color-text)">
              {{ task.description }}
            </span>
            <RiskBadge :level="task.riskLevel" />
          </div>
          <StatusBadge :status="task.status" class="mt-1" />
        </div>

        <!-- Completed tasks (strikethrough) -->
        <details v-if="completedTasks.length > 0" class="mt-2">
          <summary
            class="cursor-pointer text-xs"
            style="color: var(--color-text-dim)"
          >
            {{ completedTasks.length }} completed
          </summary>
          <div class="mt-1 space-y-1">
            <div
              v-for="task in completedTasks"
              :key="task.id"
              class="rounded-md border p-2 opacity-50"
              style="border-color: var(--color-border)"
            >
              <div class="flex items-start justify-between gap-2">
                <span
                  class="text-xs line-through"
                  style="color: var(--color-text)"
                >
                  {{ task.description }}
                </span>
                <RiskBadge :level="task.riskLevel" />
              </div>
              <StatusBadge :status="task.status" class="mt-1" />
            </div>
          </div>
        </details>
      </div>
    </div>

    <!-- View mode tab -->
    <div
      v-if="activeTab === 'view'"
      data-testid="view-mode-panel"
      class="flex-1 overflow-y-auto p-4 space-y-4"
    >
      <!-- Artifact preview cards -->
      <div v-if="artifacts.length > 0">
        <h3
          class="mb-2 text-xs font-semibold uppercase tracking-wide"
          style="color: var(--color-text-dim)"
        >
          Artifacts
        </h3>
        <div class="space-y-2">
          <div
            v-for="artifact in artifacts"
            :key="artifact.id"
            class="flex items-center gap-2 rounded-md border p-2"
            style="border-color: var(--color-border)"
          >
            <span
              class="flex h-8 w-8 shrink-0 items-center justify-center rounded text-[10px] font-bold uppercase"
              :style="artifactTypeStyle(artifact.type)"
            >
              {{ artifactTypeLabel(artifact.type) }}
            </span>
            <div class="min-w-0">
              <div
                class="truncate text-xs font-medium"
                style="color: var(--color-text)"
              >
                {{ artifact.name }}
              </div>
              <div class="text-[10px]" style="color: var(--color-text-dim)">
                {{ artifact.mimeType }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div
        v-if="artifacts.length === 0"
        class="text-xs"
        style="color: var(--color-text-dim)"
      >
        No artifacts yet
      </div>

      <!-- Multi-agent thumbnail grid -->
      <div v-if="subSessions.length > 0">
        <h3
          class="mb-2 text-xs font-semibold uppercase tracking-wide"
          style="color: var(--color-text-dim)"
        >
          Sub-Agents
        </h3>
        <div data-testid="sub-session-grid" class="grid grid-cols-2 gap-2">
          <div
            v-for="sub in subSessions"
            :key="sub.id"
            class="flex flex-col items-center justify-center rounded-md border p-3 text-center"
            style="
              border-color: var(--color-border);
              background: var(--color-surface);
            "
          >
            <span
              class="mb-1 h-8 w-8 rounded-full"
              style="background: var(--color-accent-blue)"
            />
            <span
              class="truncate w-full text-[10px] font-medium"
              style="color: var(--color-text)"
            >
              {{ sub.name }}
            </span>
            <span class="text-[10px]" style="color: var(--color-text-dim)">
              {{ sub.status }}
            </span>
          </div>
        </div>
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import type { Task } from "@/types/task";
import type { Artifact, ArtifactType } from "@/types/artifact";
import RiskBadge from "@/components/common/RiskBadge.vue";
import StatusBadge from "@/components/common/StatusBadge.vue";

export interface SubSession {
  id: string;
  name: string;
  agentType: string;
  status: string;
}

const props = defineProps<{
  tasks: Task[];
  artifacts: Artifact[];
  subSessions: SubSession[];
}>();

const activeTab = ref<"tasks" | "view">("tasks");

const activeTasks = computed(() =>
  props.tasks.filter((t) => t.status !== "completed" && t.status !== "failed"),
);

const completedTasks = computed(() =>
  props.tasks.filter((t) => t.status === "completed" || t.status === "failed"),
);

function artifactTypeLabel(type: ArtifactType): string {
  switch (type) {
    case "document":
      return "doc";
    case "code":
      return "js";
    case "report":
      return "rpt";
    case "image":
      return "img";
    case "data":
      return "csv";
    default:
      return "bin";
  }
}

function artifactTypeStyle(type: ArtifactType): Record<string, string> {
  switch (type) {
    case "document":
      return {
        background: "var(--color-accent-blue)",
        color: "white",
      };
    case "code":
      return {
        background: "var(--color-risk-green)",
        color: "var(--color-navy-deep)",
      };
    case "report":
      return {
        background: "var(--color-gold)",
        color: "var(--color-navy-deep)",
      };
    case "image":
      return {
        background: "var(--color-risk-orange)",
        color: "var(--color-navy-deep)",
      };
    case "data":
      return {
        background: "var(--color-surface)",
        color: "var(--color-text-dim)",
      };
    default:
      return {
        background: "var(--color-surface)",
        color: "var(--color-text-dim)",
      };
  }
}
</script>
