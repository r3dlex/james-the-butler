<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">
        OpenClaw Activity
      </h1>
      <div class="flex items-center gap-2">
        <span
          class="inline-block h-2 w-2 animate-pulse rounded-full"
          style="background: var(--color-accent-blue)"
        />
        <span class="text-xs" style="color: var(--color-text-dim)">Live</span>
      </div>
    </div>

    <LoadingSpinner v-if="loading" />

    <EmptyState
      v-else-if="activities.length === 0"
      message="No agent activity yet. Activity will appear here when agents are running."
    />

    <div v-else class="space-y-2">
      <div
        v-for="activity in activities"
        :key="activity.id"
        class="rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span
              class="inline-block h-1.5 w-1.5 rounded-full"
              :style="{
                background:
                  activity.status === 'running'
                    ? 'var(--color-accent-blue)'
                    : 'var(--color-text-dim)',
              }"
            />
            <p class="text-sm" style="color: var(--color-text)">
              {{ activity.description }}
            </p>
          </div>
          <span
            class="text-xs capitalize"
            style="color: var(--color-text-dim)"
            >{{ activity.status }}</span
          >
        </div>
        <div class="mt-1 flex items-center gap-3">
          <span class="text-[10px]" style="color: var(--color-text-dim)">{{
            activity.agentType
          }}</span>
          <router-link
            v-if="activity.sessionId"
            :to="`/sessions/${activity.sessionId}`"
            class="text-[10px] underline"
            style="color: var(--color-accent-blue)"
          >
            View session
          </router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

interface Activity {
  id: string;
  description: string;
  status: string;
  agentType: string;
  sessionId: string | null;
}

const activities = ref<Activity[]>([]);
const loading = ref(false);

async function fetchActivities() {
  loading.value = true;
  try {
    const data = await api.get<{ tasks: Activity[] }>(
      "/api/tasks?status=running",
    );
    activities.value = data.tasks || [];
  } catch {
    activities.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(fetchActivities);
</script>
