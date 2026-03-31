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
      v-else-if="filteredTasks.length === 0"
      message="No tasks match your filters"
    />

    <div v-else class="space-y-2">
      <div
        v-for="task in filteredTasks"
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
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useTaskStore } from "@/stores/tasks";
import RiskBadge from "@/components/common/RiskBadge.vue";
import StatusBadge from "@/components/common/StatusBadge.vue";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

const taskStore = useTaskStore();

const statusFilter = ref("");
const riskFilter = ref("");

const filteredTasks = computed(() => {
  return taskStore.tasks.filter((t) => {
    if (statusFilter.value && t.status !== statusFilter.value) return false;
    if (riskFilter.value && t.riskLevel !== riskFilter.value) return false;
    return true;
  });
});

onMounted(() => {
  taskStore.fetchTasks();
});
</script>
