<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">
      Personality
    </h1>
    <div class="max-w-lg space-y-4">
      <div>
        <label
          class="mb-1 block text-xs font-medium"
          style="color: var(--color-text-dim)"
          >Default Preset</label
        >
        <select
          v-model="selectedPreset"
          class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
          style="
            border-color: var(--color-border);
            color: var(--color-text);
            background: var(--color-navy-deep);
          "
        >
          <option v-for="p in presets" :key="p.id" :value="p.id">
            {{ p.name }}
          </option>
        </select>
        <p class="mt-1 text-xs" style="color: var(--color-text-dim)">
          {{ presetDescription }}
        </p>
      </div>
      <div>
        <label
          class="mb-1 block text-xs font-medium"
          style="color: var(--color-text-dim)"
          >Custom System Prompt (overrides preset)</label
        >
        <textarea
          v-model="customPrompt"
          rows="4"
          class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
          style="border-color: var(--color-border); color: var(--color-text)"
          placeholder="Leave empty to use the selected preset..."
        />
      </div>
      <button
        class="rounded px-3 py-1.5 text-sm font-medium"
        style="background: var(--color-gold); color: var(--color-navy-deep)"
        @click="save"
      >
        Save
      </button>
      <span
        v-if="saved"
        class="ml-2 text-xs"
        style="color: var(--color-accent-blue)"
        >Saved</span
      >
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";

const presets = [
  { id: "butler", name: "Butler", desc: "Formal, measured, and precise." },
  {
    id: "collaborator",
    name: "Collaborator",
    desc: "Conversational and direct.",
  },
  { id: "analyst", name: "Analyst", desc: "Detail-oriented, cites reasoning." },
  {
    id: "coach",
    name: "Coach",
    desc: "Encouraging, step-by-step explanations.",
  },
  {
    id: "editor",
    name: "Editor",
    desc: "Document-aware, actionable feedback.",
  },
  { id: "silent", name: "Silent", desc: "Results only, no commentary." },
];

const selectedPreset = ref("butler");
const customPrompt = ref("");
const saved = ref(false);

const presetDescription = computed(() => {
  return presets.find((p) => p.id === selectedPreset.value)?.desc || "";
});

function save() {
  saved.value = true;
  setTimeout(() => (saved.value = false), 2000);
}
</script>
