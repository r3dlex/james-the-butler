<template>
  <!-- Only visible during decomposing / awaiting_approval states -->
  <div
    v-if="plannerState !== 'executing' && plannerState !== ''"
    data-testid="planner-stream-panel"
    class="rounded-lg border p-4"
    style="border-color: var(--color-border); background: var(--color-surface)"
  >
    <!-- Header -->
    <div class="mb-3 flex items-center gap-2">
      <span
        class="h-2 w-2 animate-pulse rounded-full"
        style="background: var(--color-gold)"
      />
      <span
        class="text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Planner
      </span>
      <span
        class="rounded-full px-2 py-0.5 text-[10px] font-medium"
        :style="stateStyle"
      >
        {{ stateLabel }}
      </span>
    </div>

    <!-- Analyzing indicator -->
    <div
      v-if="plannerState === 'decomposing' && plannerSteps.length === 0"
      class="text-xs italic"
      style="color: var(--color-text-dim)"
    >
      Analyzing...
    </div>

    <!-- Task cards -->
    <div v-if="plannerSteps.length > 0" class="space-y-2">
      <div
        v-for="(step, idx) in plannerSteps"
        :key="idx"
        class="rounded-md border p-2"
        style="border-color: var(--color-border)"
      >
        <div class="flex items-start justify-between gap-2">
          <span class="text-xs" style="color: var(--color-text)">
            {{ step.description }}
          </span>
          <RiskBadge :level="step.riskLevel" />
        </div>

        <!-- Approval button for destructive tasks in confirmed mode -->
        <div
          v-if="
            step.riskLevel === 'destructive' &&
            executionMode === 'confirmed' &&
            (plannerState === 'awaiting_approval' ||
              plannerState === 'decomposing')
          "
          class="mt-2 flex gap-2"
        >
          <button
            data-testid="approve-btn"
            class="rounded px-2 py-1 text-xs font-medium transition-colors"
            style="
              background: var(--color-risk-green);
              color: var(--color-navy-deep);
            "
            @click="$emit('approve', step.taskId)"
          >
            Approve
          </button>
          <button
            data-testid="reject-btn"
            class="rounded px-2 py-1 text-xs font-medium transition-colors"
            style="background: var(--color-risk-red); color: white"
            @click="$emit('reject', step.taskId)"
          >
            Reject
          </button>
        </div>
      </div>
    </div>

    <!-- Analyzing with steps already present -->
    <div
      v-if="plannerState === 'decomposing' && plannerSteps.length > 0"
      class="mt-2 text-xs italic"
      style="color: var(--color-text-dim)"
    >
      Analyzing...
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { RiskLevel } from "@/types/task";
import type { ExecutionMode } from "@/types/session";
import RiskBadge from "@/components/common/RiskBadge.vue";

export interface PlannerStep {
  type: string;
  description: string;
  riskLevel: RiskLevel;
  taskId?: string;
}

const props = defineProps<{
  plannerSteps: PlannerStep[];
  plannerState: string;
  executionMode: ExecutionMode;
}>();

defineEmits<{
  approve: [taskId: string | undefined];
  reject: [taskId: string | undefined];
}>();

const stateLabel = computed(() => {
  switch (props.plannerState) {
    case "decomposing":
      return "Decomposing";
    case "awaiting_approval":
      return "Awaiting Approval";
    case "dispatching":
      return "Dispatching";
    default:
      return props.plannerState;
  }
});

const stateStyle = computed(() => {
  switch (props.plannerState) {
    case "decomposing":
      return {
        background: "var(--color-gold)",
        color: "var(--color-navy-deep)",
      };
    case "awaiting_approval":
      return {
        background: "var(--color-risk-orange)",
        color: "var(--color-navy-deep)",
      };
    case "dispatching":
      return { background: "var(--color-accent-blue)", color: "white" };
    default:
      return {
        background: "var(--color-surface)",
        color: "var(--color-text-dim)",
      };
  }
});
</script>
