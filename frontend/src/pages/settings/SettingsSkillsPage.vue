<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <div>
        <h1 class="text-lg font-medium" style="color: var(--color-text)">
          Skills
        </h1>
        <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
          Synced to ~/.claude/skills/
        </p>
      </div>
      <button
        class="rounded px-3 py-1.5 text-sm font-medium"
        style="background: var(--color-gold); color: var(--color-navy-deep)"
        @click="showAddForm = !showAddForm"
      >
        Add Skill
      </button>
    </div>

    <!-- Add skill form -->
    <div
      v-if="showAddForm"
      class="mb-4 rounded-md border p-4"
      style="border-color: var(--color-border)"
    >
      <h2 class="mb-3 text-sm font-medium" style="color: var(--color-text)">
        New Skill
      </h2>
      <div class="space-y-3">
        <div>
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)"
            >Name</label
          >
          <input
            v-model="newSkill.name"
            type="text"
            placeholder="my-skill"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="border-color: var(--color-border); color: var(--color-text)"
          />
        </div>
        <div>
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)"
            >Scope</label
          >
          <select
            v-model="newSkill.scope"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="
              border-color: var(--color-border);
              color: var(--color-text);
              background: var(--color-navy-deep);
            "
          >
            <option value="global">Global</option>
            <option value="user">User</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)"
            >Content</label
          >
          <textarea
            v-model="newSkill.content"
            placeholder="# Skill content&#10;&#10;Describe what this skill does..."
            rows="6"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="
              border-color: var(--color-border);
              color: var(--color-text);
              resize: vertical;
            "
          />
        </div>
        <div class="flex gap-2">
          <button
            class="rounded px-3 py-1.5 text-sm font-medium"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
            @click="addSkill"
          >
            Add
          </button>
          <button
            class="rounded border px-3 py-1.5 text-sm"
            style="border-color: var(--color-border); color: var(--color-text)"
            @click="showAddForm = false"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>

    <!-- Error message -->
    <p
      v-if="settingsStore.error"
      class="mb-4 text-xs"
      style="color: var(--color-risk-red)"
    >
      {{ settingsStore.error }}
    </p>

    <LoadingSpinner v-if="settingsStore.loading" />

    <EmptyState
      v-else-if="settingsStore.skills.length === 0"
      message="No skills installed. Click 'Add Skill' to create one."
    />

    <div v-else class="space-y-2">
      <div
        v-for="skill in settingsStore.skills"
        :key="skill.id"
        class="flex items-center justify-between rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium" style="color: var(--color-text)">
            {{ skill.name }}
          </p>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
            {{ skill.scope }} · {{ skill.content_hash.substring(0, 8) }}...
          </p>
        </div>
        <button
          class="rounded px-2 py-1 text-xs"
          style="color: var(--color-risk-red)"
          @click="confirmDelete(skill)"
        >
          Remove
        </button>
      </div>
    </div>

    <!-- Delete confirmation dialog -->
    <div
      v-if="skillToDelete"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="skillToDelete = null"
    >
      <div
        class="w-80 rounded-md border p-4"
        style="
          border-color: var(--color-border);
          background: var(--color-navy-deep);
        "
      >
        <h3 class="mb-2 text-sm font-medium" style="color: var(--color-text)">
          Delete Skill
        </h3>
        <p class="mb-4 text-xs" style="color: var(--color-text-dim)">
          Are you sure you want to delete "{{ skillToDelete.name }}"? This
          action cannot be undone.
        </p>
        <div class="flex gap-2">
          <button
            class="flex-1 rounded px-3 py-1.5 text-sm font-medium"
            style="background: var(--color-risk-red); color: white"
            @click="deleteSkill"
          >
            Delete
          </button>
          <button
            class="flex-1 rounded border px-3 py-1.5 text-sm"
            style="border-color: var(--color-border); color: var(--color-text)"
            @click="skillToDelete = null"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useSettingsStore } from "@/stores/settings";
import type { Skill } from "@/types/skill";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

const settingsStore = useSettingsStore();

const showAddForm = ref(false);
const skillToDelete = ref<Skill | null>(null);

const newSkill = ref<{ name: string; scope: string; content: string }>({
  name: "",
  scope: "global",
  content: "",
});

async function addSkill() {
  if (!newSkill.value.name.trim()) return;
  if (!newSkill.value.content.trim()) return;

  await settingsStore.addSkill({
    name: newSkill.value.name.trim(),
    scope: newSkill.value.scope,
    content: newSkill.value.content,
  });

  if (!settingsStore.error) {
    newSkill.value = { name: "", scope: "global", content: "" };
    showAddForm.value = false;
  }
}

function confirmDelete(skill: Skill) {
  skillToDelete.value = skill;
}

async function deleteSkill() {
  if (!skillToDelete.value) return;
  await settingsStore.removeSkill(skillToDelete.value.id);
  skillToDelete.value = null;
}

onMounted(() => {
  settingsStore.fetchSkills();
});
</script>
