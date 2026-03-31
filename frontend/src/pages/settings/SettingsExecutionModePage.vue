<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">
      Execution Mode
    </h1>
    <div class="max-w-lg space-y-4">
      <div>
        <label
          class="mb-1 block text-xs font-medium"
          style="color: var(--color-text-dim)"
          >Account Default</label
        >
        <select
          v-model="mode"
          class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
          style="
            border-color: var(--color-border);
            color: var(--color-text);
            background: var(--color-navy-deep);
          "
        >
          <option value="direct">Direct — agents execute immediately</option>
          <option value="confirmed">
            Confirmed — destructive actions require approval
          </option>
        </select>
      </div>
      <p class="text-xs" style="color: var(--color-text-dim)">
        Projects and sessions can override this setting. The most specific level
        wins.
      </p>
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
import { ref } from "vue";

const mode = ref("direct");
const saved = ref(false);

function save() {
  saved.value = true;
  setTimeout(() => (saved.value = false), 2000);
}
</script>
