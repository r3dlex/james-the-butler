<template>
  <div
    class="rounded border p-4"
    style="
      border-color: var(--color-border);
      background: var(--color-navy-deep);
    "
  >
    <div class="flex items-center justify-between">
      <div class="flex items-center gap-2">
        <span
          class="status-dot inline-block h-2.5 w-2.5 rounded-full"
          :class="statusDotClass"
          :data-status="provider.status"
        />
        <span class="text-sm font-medium" style="color: var(--color-text)">{{
          provider.displayName
        }}</span>
      </div>
      <div class="flex items-center gap-2">
        <button
          class="rounded px-2 py-1 text-xs font-medium"
          style="
            border: 1px solid var(--color-border);
            color: var(--color-text-dim);
          "
          :disabled="testing"
          @click="onTestConnection"
        >
          <span v-if="testing" class="loading-spinner">...</span>
          <span v-else>Test Connection</span>
        </button>
        <button
          class="rounded px-2 py-1 text-xs font-medium"
          style="background: var(--color-gold); color: var(--color-navy-deep)"
          @click="$emit('configure', provider)"
        >
          Configure
        </button>
      </div>
    </div>

    <div v-if="provider.models.length > 0" class="mt-3">
      <p class="mb-1 text-xs" style="color: var(--color-text-dim)">Models</p>
      <ul class="space-y-0.5">
        <li
          v-for="model in provider.models"
          :key="model"
          class="text-xs"
          style="color: var(--color-text)"
        >
          {{ model }}
        </li>
      </ul>
    </div>
    <div v-else class="mt-2 text-xs" style="color: var(--color-text-dim)">
      No models
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { useProviderStore } from "@/stores/providers";
import type { ProviderConfig } from "@/types/provider";

const props = defineProps<{
  provider: ProviderConfig;
}>();

defineEmits<{
  configure: [provider: ProviderConfig];
}>();

const providerStore = useProviderStore();
const testing = ref(false);

const statusDotClass = computed(() => {
  switch (props.provider.status) {
    case "connected":
      return "bg-green-500";
    case "failed":
      return "bg-red-500";
    default:
      return "bg-yellow-400";
  }
});

async function onTestConnection() {
  testing.value = true;
  try {
    await providerStore.testConnection(props.provider.id);
  } finally {
    testing.value = false;
  }
}
</script>
