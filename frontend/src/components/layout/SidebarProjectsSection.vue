<template>
  <div class="px-2 py-1">
    <!-- Section header -->
    <div class="mb-1 flex items-center justify-between px-1">
      <span
        class="text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-text-dim)"
      >
        Projects
      </span>
      <RouterLink
        to="/projects"
        class="text-xs transition-colors hover:text-[var(--color-gold)]"
        style="color: var(--color-text-dim)"
      >
        More →
      </RouterLink>
    </div>

    <!-- Project list -->
    <div v-if="recentProjects.length" class="space-y-0.5">
      <div v-for="project in recentProjects" :key="project.id">
        <!-- Project row -->
        <RouterLink
          :to="`/projects/${project.id}`"
          class="flex items-center gap-1.5 rounded-md px-2 py-1 text-sm transition-colors hover:bg-[var(--color-surface)]"
          :style="{
            color: route.path.startsWith(`/projects/${project.id}`)
              ? 'var(--color-gold)'
              : 'var(--color-text)',
            background: route.path.startsWith(`/projects/${project.id}`)
              ? 'var(--color-surface)'
              : undefined,
          }"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="13"
            height="13"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            class="shrink-0"
            style="color: var(--color-text-dim)"
          >
            <path
              d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"
            />
          </svg>
          <span class="truncate">{{ project.name }}</span>
        </RouterLink>

        <!-- Sessions under this project (up to 3) -->
        <RouterLink
          v-for="session in recentSessionsForProject(project.id)"
          :key="session.id"
          :to="`/sessions/${session.id}`"
          class="ml-5 flex items-center gap-1.5 rounded-md px-2 py-0.5 text-xs transition-colors hover:bg-[var(--color-surface)]"
          :style="{
            color:
              route.params.id === session.id
                ? 'var(--color-gold)'
                : 'var(--color-text-dim)',
          }"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="11"
            height="11"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            class="shrink-0"
          >
            <path
              d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"
            />
          </svg>
          <span class="truncate">{{ session.name }}</span>
        </RouterLink>
      </div>
    </div>

    <!-- Empty state -->
    <p v-else class="px-2 py-1 text-xs" style="color: var(--color-text-dim)">
      No projects yet
    </p>

    <!-- New Project button -->
    <button
      type="button"
      class="new-project-btn mt-1 flex w-full items-center gap-1.5 rounded-md px-2 py-1 text-xs transition-colors"
      style="color: var(--color-text-dim)"
      @click="newProject"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="12"
        height="12"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        class="shrink-0"
      >
        <path d="M5 12h14" />
        <path d="M12 5v14" />
      </svg>
      New Project
    </button>
  </div>
</template>

<script setup lang="ts">
import { useRoute, useRouter, RouterLink } from "vue-router";
import { useProjectStore } from "@/stores/projects";

const route = useRoute();
const router = useRouter();
const projectStore = useProjectStore();

const recentProjects = projectStore.recentProjects;
const recentSessionsForProject = projectStore.recentSessionsForProject;

function newProject() {
  router.push("/projects/new");
}
</script>

<style scoped>
.new-project-btn:hover {
  color: var(--color-gold) !important;
  background: var(--color-surface);
}
</style>
