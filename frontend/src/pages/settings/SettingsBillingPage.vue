<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">Billing &amp; Usage</h1>
    <div class="max-w-lg space-y-4">
      <div class="rounded-md border p-4" style="border-color: var(--color-border)">
        <p class="text-sm" style="color: var(--color-text)">Token Usage</p>
        <p class="mt-1 text-xs" style="color: var(--color-text-dim)">
          View your token usage across all sessions. Detailed billing coming in a future update.
        </p>
        <div class="mt-3">
          <LoadingSpinner v-if="loading" />
          <div v-else-if="usage.length > 0" class="space-y-2">
            <div v-for="entry in usage" :key="entry.model" class="flex items-center justify-between">
              <span class="text-sm" style="color: var(--color-text)">{{ entry.model }}</span>
              <span class="text-xs" style="color: var(--color-text-dim)">
                {{ entry.totalInput }} in / {{ entry.totalOutput }} out — ${{ entry.totalCost }}
              </span>
            </div>
          </div>
          <p v-else class="text-xs" style="color: var(--color-text-dim)">No usage recorded yet.</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";

interface UsageEntry {
  model: string;
  totalInput: number;
  totalOutput: number;
  totalCost: string;
}

const usage = ref<UsageEntry[]>([]);
const loading = ref(false);

async function fetchUsage() {
  loading.value = true;
  try {
    const data = await api.get<{ usage: UsageEntry[] }>("/api/tokens/usage");
    usage.value = data.usage || [];
  } catch {
    usage.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(fetchUsage);
</script>
