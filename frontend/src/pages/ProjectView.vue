<template>
  <div class="p-6">
    <LoadingSpinner v-if="loading" />

    <template v-else-if="project">
      <div class="mb-4 flex items-center justify-between">
        <div>
          <h1 class="text-lg font-medium" style="color: var(--color-text)">
            {{ project.name }}
          </h1>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
            {{ project.executionMode || "direct" }} mode
          </p>
        </div>
        <router-link
          :to="`/projects/${project.id}/settings`"
          class="rounded border px-3 py-1.5 text-sm transition-colors hover:bg-[var(--color-surface)]"
          style="border-color: var(--color-border); color: var(--color-text)"
        >
          Settings
        </router-link>
      </div>

      <h2 class="mb-2 text-sm font-medium" style="color: var(--color-text-dim)">
        Sessions
      </h2>

      <EmptyState
        v-if="sessions.length === 0"
        message="No sessions in this project yet."
      />

      <div v-else class="space-y-2">
        <router-link
          v-for="session in sessions"
          :key="session.id"
          :to="`/sessions/${session.id}`"
          class="block rounded-md border p-3 transition-colors hover:bg-[var(--color-surface)]"
          style="border-color: var(--color-border)"
        >
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium" style="color: var(--color-text)">
                {{ session.name }}
              </p>
              <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
                {{ session.agentType }} · {{ session.status }}
              </p>
            </div>
            <span class="text-xs" style="color: var(--color-text-dim)">{{
              formatDate(session.lastUsedAt)
            }}</span>
          </div>
        </router-link>
      </div>
    </template>

    <EmptyState v-else message="Project not found." />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useRoute } from "vue-router";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

interface Project {
  id: string;
  name: string;
  executionMode: string | null;
}

interface Session {
  id: string;
  name: string;
  agentType: string;
  status: string;
  lastUsedAt: string | null;
}

const route = useRoute();
const project = ref<Project | null>(null);
const sessions = ref<Session[]>([]);
const loading = ref(false);

async function fetchProject() {
  loading.value = true;
  try {
    const data = await api.get<{ project: Project; sessions: Session[] }>(
      `/api/projects/${route.params.id}`,
    );
    project.value = data.project;
    sessions.value = data.sessions || [];
  } catch {
    project.value = null;
  } finally {
    loading.value = false;
  }
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "";
  return new Date(dateStr).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
  });
}

onMounted(fetchProject);
</script>
