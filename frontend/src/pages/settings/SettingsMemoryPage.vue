<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">
      Memory Settings
    </h1>
    <div class="max-w-lg space-y-4">
      <div
        class="flex items-center justify-between rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <div>
          <p class="text-sm" style="color: var(--color-text)">
            Auto-extract memories
          </p>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
            Automatically extract key facts from conversations
          </p>
        </div>
        <button
          class="relative h-5 w-9 rounded-full transition-colors"
          :style="{
            background: autoExtract
              ? 'var(--color-gold)'
              : 'var(--color-border)',
          }"
          @click="autoExtract = !autoExtract"
        >
          <span
            class="absolute top-0.5 h-4 w-4 rounded-full bg-white transition-transform"
            :style="{
              transform: autoExtract ? 'translateX(16px)' : 'translateX(2px)',
            }"
          />
        </button>
      </div>
      <div
        class="flex items-center justify-between rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <div>
          <p class="text-sm" style="color: var(--color-text)">
            Inject memories into context
          </p>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
            Include relevant memories when starting conversations
          </p>
        </div>
        <button
          class="relative h-5 w-9 rounded-full transition-colors"
          :style="{
            background: injectMemories
              ? 'var(--color-gold)'
              : 'var(--color-border)',
          }"
          @click="injectMemories = !injectMemories"
        >
          <span
            class="absolute top-0.5 h-4 w-4 rounded-full bg-white transition-transform"
            :style="{
              transform: injectMemories
                ? 'translateX(16px)'
                : 'translateX(2px)',
            }"
          />
        </button>
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
import { ref } from "vue";

const autoExtract = ref(true);
const injectMemories = ref(true);
const saved = ref(false);

function save() {
  saved.value = true;
  setTimeout(() => (saved.value = false), 2000);
}
</script>
