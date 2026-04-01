<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">
        Tasks
      </h1>

      <!-- Filters -->
      <div class="flex gap-2">
        <select
          v-model="statusFilter"
          class="rounded border bg-transparent px-2 py-1 text-xs"
          style="border-color: var(--color-border); color: var(--color-text)"
        >
          <option value="">All statuses</option>
          <option value="pending">Pending</option>
          <option value="running">Running</option>
          <option value="completed">Completed</option>
          <option value="failed">Failed</option>
          <option value="blocked">Blocked</option>
        </select>
        <select
          v-model="riskFilter"
          class="rounded border bg-transparent px-2 py-1 text-xs"
          style="border-color: var(--color-border); color: var(--color-text)"
        >
          <option value="">All risk levels</option>
          <option value="read_only">Read-only</option>
          <option value="additive">Additive</option>
          <option value="destructive">Destructive</option>
        </select>
      </div>
    </div>

    <LoadingSpinner v-if="taskStore.loading" />

    <EmptyState
      v-else-if="orderedTasks.length === 0"
      message="No tasks match your filters"
    />

    <div v-else class="space-y-4">
      <div
        v-for="(group, sessionId) in groupedTasks"
        :key="sessionId"
        class="space-y-2"
      >
        <p
          class="text-[10px] font-medium uppercase tracking-wide"
          style="color: var(--color-text-dim)"
        >
          Session {{ String(sessionId).slice(0, 8) }}
        </p>

        <div
          v-for="task in group"
          :key="task.id"
          class="flex items-center gap-3 rounded-md border p-3"
          style="border-color: var(--color-border)"
        >
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span
                class="text-sm"
                :class="{
                  'line-through opacity-50': task.status === 'completed',
                }"
                style="color: var(--color-text)"
              >
                {{ task.description }}
              </span>
              <RiskBadge :level="task.riskLevel" />
            </div>
            <div class="mt-1 flex items-center gap-2">
              <StatusBadge :status="task.status" />
              <span class="text-[10px]" style="color: var(--color-text-dim)">
                {{ task.sessionId?.slice(0, 8) }}
              </span>
            </div>
          </div>

          <!-- Approve/reject for pending destructive tasks -->
          <div
            v-if="task.status === 'pending' && task.riskLevel === 'destructive'"
            class="flex gap-1"
          >
            <button
              class="rounded px-2 py-1 text-xs font-medium"
              style="
                background: var(--color-risk-green);
                color: var(--color-navy-deep);
              "
              @click="taskStore.approveTask(task.id)"
            >
              Approve
            </button>
            <button
              class="rounded px-2 py-1 text-xs font-medium"
              style="background: var(--color-risk-red); color: white"
              @click="taskStore.rejectTask(task.id)"
            >
              Reject
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { onMounted } from "vue";
import { useTaskStore } from "@/stores/tasks";
import RiskBadge from "@/components/common/RiskBadge.vue";
import StatusBadge from "@/components/common/StatusBadge.vue";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";
import type { Task } from "@/types/task";

const taskStore = useTaskStore();

const statusFilter = ref("");
const riskFilter = ref("");

const STATUS_ORDER: Record<string, number> = {
  running: 0,
  pending: 1,
  blocked: 2,
  failed: 3,
  completed: 4,
};

const orderedTasks = computed(() => {
  return taskStore.tasks
    .filter((t) => {
      if (statusFilter.value && t.status !== statusFilter.value) return false;
      if (riskFilter.value && t.riskLevel !== riskFilter.value) return false;
      return true;
    })
    .slice()
    .sort((a, b) => {
      const ao = STATUS_ORDER[a.status] ?? 99;
      const bo = STATUS_ORDER[b.status] ?? 99;
      return ao - bo;
    });
});

const groupedTasks = computed(() => {
  const groups: Record<string, Task[]> = {};
  for (const task of orderedTasks.value) {
    const sid = task.sessionId ?? "unknown";
    if (!groups[sid]) groups[sid] = [];
    groups[sid].push(task);
  }
  return groups;
});

onMounted(() => {
  taskStore.fetchTasks();
});
</script>
