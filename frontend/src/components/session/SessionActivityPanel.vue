<template>
  <aside
    class="flex w-72 flex-col overflow-y-auto border-l p-4"
    style="border-color: var(--color-border)"
  >
    <h3
      class="mb-3 text-xs font-semibold uppercase tracking-wide"
      style="color: var(--color-text-dim)"
    >
      Tasks
    </h3>
    <div
      v-if="tasks.length === 0"
      class="text-xs"
      style="color: var(--color-text-dim)"
    >
      No tasks yet
    </div>
    <div v-else class="space-y-2">
      <div
        v-for="task in tasks"
        :key="task.id"
        class="rounded-md border p-2"
        style="border-color: var(--color-border)"
      >
        <div class="flex items-start justify-between gap-2">
          <span
            class="text-xs"
            :class="{ 'line-through opacity-50': task.status === 'completed' }"
            style="color: var(--color-text)"
          >
            {{ task.description }}
          </span>
          <RiskBadge :level="task.riskLevel" />
        </div>
        <StatusBadge :status="task.status" class="mt-1" />
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import type { Task } from "@/types/task";
import RiskBadge from "@/components/common/RiskBadge.vue";
import StatusBadge from "@/components/common/StatusBadge.vue";

defineProps<{ tasks: Task[] }>();
</script>
