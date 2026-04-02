<template>
  <div class="p-6">
    <LoadingSpinner v-if="projectStore.loading" />

    <template v-else-if="projectStore.currentProject">
      <div class="mb-4 flex items-center justify-between">
        <div>
          <h1 class="text-lg font-medium" style="color: var(--color-text)">
            {{ projectStore.currentProject.name }}
          </h1>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
            {{ projectStore.currentProject.executionMode || "direct" }} mode
          </p>
          <p
            v-if="projectStore.currentProject.description"
            class="mt-1 text-sm"
            style="color: var(--color-text-dim)"
          >
            {{ projectStore.currentProject.description }}
          </p>
        </div>
        <div class="flex items-center gap-2">
          <button
            class="rounded px-3 py-1.5 text-sm font-medium"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
            @click="showNewSession = true"
          >
            New Session
          </button>
          <router-link
            :to="`/projects/${projectStore.currentProject.id}/settings`"
            class="rounded border px-3 py-1.5 text-sm transition-colors hover:bg-[var(--color-surface)]"
            style="border-color: var(--color-border); color: var(--color-text)"
          >
            Settings
          </router-link>
        </div>
      </div>

      <NewSessionModal
        :open="showNewSession"
        :project-id="projectStore.currentProject.id"
        @create="onCreateSession"
        @cancel="showNewSession = false"
      />

      <!-- Repository health indicators -->
      <div
        class="mb-4 rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <h2
          class="mb-2 text-xs font-medium uppercase tracking-wide"
          style="color: var(--color-text-dim)"
        >
          Repository Health
        </h2>
        <div class="flex gap-4">
          <div class="flex items-center gap-1.5">
            <span
              class="inline-block h-2 w-2 rounded-full"
              style="background: var(--color-risk-green)"
            ></span>
            <span class="text-xs" style="color: var(--color-text-dim)"
              >CI Passing</span
            >
          </div>
          <div class="flex items-center gap-1.5">
            <span
              class="inline-block h-2 w-2 rounded-full"
              style="background: var(--color-risk-green)"
            ></span>
            <span class="text-xs" style="color: var(--color-text-dim)"
              >No open alerts</span
            >
          </div>
          <div
            v-if="projectStore.currentProject.repoUrl"
            class="flex items-center gap-1.5"
          >
            <a
              :href="projectStore.currentProject.repoUrl"
              target="_blank"
              rel="noopener"
              class="text-xs"
              style="color: var(--color-accent-blue)"
              >View repo</a
            >
          </div>
        </div>
      </div>

      <h2 class="mb-2 text-sm font-medium" style="color: var(--color-text-dim)">
        Sessions
      </h2>

      <EmptyState
        v-if="projectStore.currentProjectSessions.length === 0"
        message="No sessions in this project yet."
      />

      <div v-else class="space-y-2">
        <router-link
          v-for="session in projectStore.currentProjectSessions"
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
import { useRoute, useRouter } from "vue-router";
import { useProjectStore } from "@/stores/projects";
import { useSessionStore } from "@/stores/sessions";
import type { ExecutionMode } from "@/types/session";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";
import NewSessionModal from "@/components/session/NewSessionModal.vue";

const route = useRoute();
const router = useRouter();
const projectStore = useProjectStore();
const sessionStore = useSessionStore();

const showNewSession = ref(false);

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "";
  return new Date(dateStr).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
  });
}

interface NewSessionPayload {
  name?: string;
  executionMode: ExecutionMode;
  workingDirectories: string[];
}

async function onCreateSession(payload: NewSessionPayload) {
  showNewSession.value = false;
  const id = route.params.id as string;
  const session = await sessionStore.createSession({
    agentType: "chat",
    hostId: "primary",
    projectId: id,
    name: payload.name,
    executionMode: payload.executionMode,
    workingDirectories: payload.workingDirectories,
  });
  if (session) {
    await projectStore.fetchProjectSessions(id);
    router.push(`/sessions/${session.id}`);
  }
}

onMounted(async () => {
  const id = route.params.id as string;
  await projectStore.fetchProject(id);
  await projectStore.fetchProjectSessions(id);
});
</script>
