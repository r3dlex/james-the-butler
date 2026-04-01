<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">
      Models
    </h1>

    <LoadingSpinner v-if="settingsStore.loading" />

    <div v-else class="max-w-lg space-y-4">
      <div>
        <label
          class="mb-1 block text-xs font-medium"
          style="color: var(--color-text-dim)"
          >Default Model</label
        >
        <select
          v-model="selectedModel"
          class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
          style="
            border-color: var(--color-border);
            color: var(--color-text);
            background: var(--color-navy-deep);
          "
        >
          <option v-for="m in models" :key="m" :value="m">{{ m }}</option>
        </select>
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
      <span
        v-if="settingsStore.error"
        class="ml-2 text-xs"
        style="color: var(--color-risk-red)"
        >{{ settingsStore.error }}</span
      >
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from "vue";
import { useSettingsStore } from "@/stores/settings";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";

const settingsStore = useSettingsStore();

const models = [
  "claude-sonnet-4-20250514",
  "claude-opus-4-20250514",
  "claude-haiku-3-20250307",
];
const selectedModel = ref("claude-sonnet-4-20250514");
const saved = ref(false);

watch(
  () => settingsStore.modelConfig,
  (config) => {
    if (config?.model) selectedModel.value = config.model;
  },
);

async function save() {
  await settingsStore.saveModelConfig({ model: selectedModel.value });
  if (!settingsStore.error) {
    saved.value = true;
    setTimeout(() => (saved.value = false), 2000);
  }
}

onMounted(() => {
  settingsStore.fetchModelConfig();
});
</script>
