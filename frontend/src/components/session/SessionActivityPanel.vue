<template>
  <aside
    class="flex w-72 flex-col overflow-y-auto border-l p-4"
    style="border-color: var(--color-border)"
  >
    <!-- Planner status -->
    <div class="mb-3 flex items-center gap-2">
      <h3
        class="text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Tasks
      </h3>
      <span
        v-if="plannerStatus"
        class="rounded-full px-2 py-0.5 text-[10px] font-medium"
        :style="plannerStatusStyle"
      >
        {{ plannerStatus }}
      </span>
    </div>

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
        <div class="mt-1 flex items-center gap-2">
          <StatusBadge :status="task.status" />
          <!-- Elapsed time for running tasks -->
          <span
            v-if="task.status === 'running' && task.startedAt"
            class="text-[10px] tabular-nums"
            style="color: var(--color-text-dim)"
          >
            {{ elapsed(task.startedAt) }}
          </span>
        </div>

        <!-- Approval buttons for pending destructive tasks -->
        <div
          v-if="task.status === 'pending' && task.riskLevel === 'destructive'"
          class="mt-2 flex gap-2"
        >
          <button
            class="rounded px-2 py-1 text-xs font-medium transition-colors"
            style="
              background: var(--color-risk-green);
              color: var(--color-navy-deep);
            "
            @click="$emit('approve', task.id)"
          >
            Approve
          </button>
          <button
            class="rounded px-2 py-1 text-xs font-medium transition-colors"
            style="
              background: var(--color-risk-red);
              color: white;
            "
            @click="$emit('reject', task.id)"
          >
            Reject
          </button>
        </div>
      </div>

      <!-- Completed tasks (collapsed) -->
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
  </aside>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { Task } from "@/types/task";
import RiskBadge from "@/components/common/RiskBadge.vue";
import StatusBadge from "@/components/common/StatusBadge.vue";

const props = defineProps<{
  tasks: Task[];
  plannerStatus?: string;
}>();

defineEmits<{
  approve: [taskId: string];
  reject: [taskId: string];
}>();

const activeTasks = computed(() =>
  props.tasks.filter(
    (t) => t.status !== "completed" && t.status !== "failed",
  ),
);

const completedTasks = computed(() =>
  props.tasks.filter(
    (t) => t.status === "completed" || t.status === "failed",
  ),
);

const plannerStatusStyle = computed(() => {
  switch (props.plannerStatus) {
    case "decomposing":
      return { background: "var(--color-gold)", color: "var(--color-navy-deep)" };
    case "dispatching":
      return { background: "var(--color-accent-blue)", color: "white" };
    case "awaiting approval":
      return { background: "var(--color-risk-orange)", color: "var(--color-navy-deep)" };
    default:
      return { background: "var(--color-surface)", color: "var(--color-text-dim)" };
  }
});

function elapsed(startedAt: string): string {
  const ms = Date.now() - new Date(startedAt).getTime();
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const mins = Math.floor(seconds / 60);
  return `${mins}m ${seconds % 60}s`;
}
</script>
