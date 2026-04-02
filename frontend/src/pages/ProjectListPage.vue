<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">
        Projects
      </h1>
      <div class="flex items-center gap-3">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Filter projects..."
          class="rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
          style="border-color: var(--color-border); color: var(--color-text)"
        />
        <button
          class="rounded px-3 py-1.5 text-sm font-medium"
          style="background: var(--color-gold); color: var(--color-navy-deep)"
          @click="showCreate = true"
        >
          New Project
        </button>
      </div>
    </div>

    <!-- Create project inline form -->
    <div
      v-if="showCreate"
      class="mb-4 rounded-md border p-4"
      style="border-color: var(--color-border)"
    >
      <div class="flex flex-col gap-3">
        <div class="flex items-end gap-3">
          <div class="flex-1">
            <label
              class="mb-1 block text-xs"
              style="color: var(--color-text-dim)"
              >Project name</label
            >
            <input
              v-model="newName"
              type="text"
              class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
              "
              placeholder="My Project"
              @keydown.enter="createProject"
            />
          </div>
        </div>
        <div>
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)"
            >Workspace folder (optional)</label
          >
          <input
            v-model="newWorkspace"
            type="text"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="border-color: var(--color-border); color: var(--color-text)"
            placeholder="/home/user/my-project"
          />
        </div>
        <div class="flex items-center gap-3">
          <button
            class="rounded px-3 py-1.5 text-sm font-medium"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
            @click="createProject"
          >
            Create
          </button>
          <button
            class="text-sm"
            style="color: var(--color-text-dim)"
            @click="
              showCreate = false;
              newName = '';
              newWorkspace = '';
            "
          >
            Cancel
          </button>
        </div>
      </div>
    </div>

    <LoadingSpinner v-if="loading" />

    <EmptyState
      v-else-if="filteredProjects.length === 0"
      message="No projects yet. Create one to organize your sessions."
    />

    <div v-else class="space-y-2">
      <router-link
        v-for="project in filteredProjects"
        :key="project.id"
        :to="`/projects/${project.id}`"
        class="block rounded-md border p-3 transition-colors hover:bg-[var(--color-surface)]"
        style="border-color: var(--color-border)"
      >
        <div class="flex items-center justify-between">
          <div>
            <p class="text-sm font-medium" style="color: var(--color-text)">
              {{ project.name }}
            </p>
            <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
              {{ project.sessionCount ?? 0 }} sessions
              <span v-if="project.executionMode">
                · {{ project.executionMode }} mode</span
              >
            </p>
          </div>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            style="color: var(--color-text-dim)"
          >
            <path d="m9 18 6-6-6-6" />
          </svg>
        </div>
      </router-link>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

const props = withDefaults(
  defineProps<{
    autoCreate?: boolean;
  }>(),
  { autoCreate: false },
);

interface Project {
  id: string;
  name: string;
  executionMode: string | null;
  sessionCount?: number;
}

const projects = ref<Project[]>([]);
const loading = ref(false);
const searchQuery = ref("");
const showCreate = ref(false);
const newName = ref("");
const newWorkspace = ref("");

const filteredProjects = computed(() => {
  const q = searchQuery.value.toLowerCase();
  if (!q) return projects.value;
  return projects.value.filter((p) => p.name.toLowerCase().includes(q));
});

async function fetchProjects() {
  loading.value = true;
  try {
    const data = await api.get<{ projects: Project[] }>("/api/projects");
    projects.value = data.projects;
  } catch {
    projects.value = [];
  } finally {
    loading.value = false;
  }
}

async function createProject() {
  const name = newName.value.trim();
  if (!name) return;
  try {
    const data = await api.post<{ project: Project }>("/api/projects", {
      name,
      working_directories: newWorkspace.value
        ? [newWorkspace.value.trim()]
        : [],
    });
    projects.value.unshift(data.project);
    newName.value = "";
    newWorkspace.value = "";
    showCreate.value = false;
  } catch {
    // handle error
  }
}

onMounted(() => {
  fetchProjects();
  if (props.autoCreate) {
    showCreate.value = true;
  }
});
</script>
