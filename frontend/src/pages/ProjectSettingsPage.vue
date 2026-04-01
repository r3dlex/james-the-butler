<template>
  <div class="p-6">
    <LoadingSpinner v-if="loading" />

    <template v-else-if="project">
      <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">
        {{ project.name }} — Settings
      </h1>

      <div class="max-w-lg space-y-4">
        <!-- Name -->
        <div>
          <label
            class="mb-1 block text-xs font-medium"
            style="color: var(--color-text-dim)"
            >Project Name</label
          >
          <input
            v-model="editName"
            type="text"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="border-color: var(--color-border); color: var(--color-text)"
          />
        </div>

        <!-- Execution Mode -->
        <div>
          <label
            class="mb-1 block text-xs font-medium"
            style="color: var(--color-text-dim)"
            >Execution Mode</label
          >
          <select
            v-model="editMode"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="
              border-color: var(--color-border);
              color: var(--color-text);
              background: var(--color-navy-deep);
            "
          >
            <option value="">Inherit from user</option>
            <option value="direct">Direct</option>
            <option value="confirmed">Confirmed</option>
          </select>
        </div>

        <div class="flex items-center gap-3">
          <button
            class="rounded px-3 py-1.5 text-sm font-medium"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
            @click="saveSettings"
          >
            Save
          </button>
          <span
            v-if="saved"
            class="text-xs"
            style="color: var(--color-accent-blue)"
            >Saved</span
          >
        </div>

        <!-- Danger zone -->
        <div
          class="mt-8 rounded-md border p-4"
          style="border-color: var(--color-risk-red)"
        >
          <h3 class="text-sm font-medium" style="color: var(--color-risk-red)">
            Danger Zone
          </h3>
          <p class="mt-1 text-xs" style="color: var(--color-text-dim)">
            Deleting a project is permanent and cannot be undone.
          </p>
          <button
            class="mt-2 rounded px-3 py-1.5 text-sm font-medium"
            style="background: var(--color-risk-red); color: white"
            @click="deleteProject"
          >
            Delete Project
          </button>
        </div>
      </div>
    </template>

    <EmptyState v-else message="Project not found." />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

interface Project {
  id: string;
  name: string;
  executionMode: string | null;
}

const route = useRoute();
const router = useRouter();
const project = ref<Project | null>(null);
const loading = ref(false);
const editName = ref("");
const editMode = ref("");
const saved = ref(false);

async function fetchProject() {
  loading.value = true;
  try {
    const data = await api.get<{ project: Project }>(
      `/api/projects/${route.params.id}`,
    );
    project.value = data.project;
    editName.value = data.project.name;
    editMode.value = data.project.executionMode || "";
  } catch {
    project.value = null;
  } finally {
    loading.value = false;
  }
}

async function saveSettings() {
  if (!project.value) return;
  try {
    const data = await api.put<{ project: Project }>(
      `/api/projects/${project.value.id}`,
      {
        name: editName.value.trim(),
        execution_mode: editMode.value || null,
      },
    );
    project.value = data.project;
    saved.value = true;
    setTimeout(() => (saved.value = false), 2000);
  } catch {
    // handle error
  }
}

async function deleteProject() {
  if (!project.value) return;
  if (!confirm("Are you sure you want to delete this project?")) return;
  try {
    await api.delete(`/api/projects/${project.value.id}`);
    router.push("/projects");
  } catch {
    // handle error
  }
}

onMounted(fetchProject);
</script>
