<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">
      Models
    </h1>

    <LoadingSpinner v-if="providerStore.loading" />

    <div v-else class="max-w-2xl space-y-6">
      <!-- Configured providers -->
      <div v-if="providerStore.providers.length > 0" class="space-y-3">
        <h2 class="text-sm font-medium" style="color: var(--color-text-dim)">
          Configured Providers
        </h2>
        <ProviderCard
          v-for="provider in providerStore.providers"
          :key="provider.id"
          :provider="provider"
          @remove="submitRemove"
        />
      </div>

      <!-- Empty state -->
      <div
        v-else
        class="rounded border p-6 text-center"
        style="border-color: var(--color-border)"
      >
        <p class="mb-2 text-sm font-medium" style="color: var(--color-text)">
          No providers configured
        </p>
        <p class="text-xs" style="color: var(--color-text-dim)">
          Add a provider below to get started. Configure your API keys to
          connect to AI models.
        </p>
      </div>

      <!-- Add Provider section -->
      <div
        class="rounded border p-4"
        style="
          border-color: var(--color-border);
          background: var(--color-navy-deep);
        "
      >
        <h2 class="mb-3 text-sm font-medium" style="color: var(--color-text)">
          Add Provider
        </h2>

        <div class="space-y-3">
          <div>
            <label
              class="mb-1 block text-xs font-medium"
              style="color: var(--color-text-dim)"
              >Provider Type</label
            >
            <select
              v-model="newProvider.providerType"
              class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
            >
              <option value="anthropic">Anthropic</option>
              <option value="openai">OpenAI</option>
              <option value="openai_codex">OpenAI Codex</option>
              <option value="gemini">Gemini</option>
              <option value="minimax">MiniMax</option>
              <option value="ollama">Ollama (Local)</option>
              <option value="lm_studio">LM Studio (Local)</option>
              <option value="openai_compatible">OpenAI Compatible</option>
            </select>
          </div>

          <div>
            <label
              class="mb-1 block text-xs font-medium"
              style="color: var(--color-text-dim)"
              >Display Name</label
            >
            <input
              v-model="newProvider.displayName"
              type="text"
              placeholder="e.g. My Anthropic Account"
              class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
            />
          </div>

          <div>
            <label
              class="mb-1 block text-xs font-medium"
              style="color: var(--color-text-dim)"
              >Auth Method</label
            >
            <select
              v-model="newProvider.authMethod"
              class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
            >
              <option value="api_key">API Key</option>
              <option value="oauth">OAuth</option>
              <option value="none">None</option>
            </select>
          </div>

          <div v-if="newProvider.authMethod === 'api_key'">
            <label
              class="mb-1 block text-xs font-medium"
              style="color: var(--color-text-dim)"
              >API Key</label
            >
            <input
              v-model="newProvider.apiKey"
              type="password"
              placeholder="sk-..."
              class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
            />
          </div>

          <div
            v-if="
              newProvider.providerType === 'ollama' ||
              newProvider.providerType === 'lm_studio' ||
              newProvider.providerType === 'openai_compatible' ||
              newProvider.providerType === 'minimax'
            "
          >
            <label
              class="mb-1 block text-xs font-medium"
              style="color: var(--color-text-dim)"
              >Base URL</label
            >
            <input
              v-model="newProvider.baseUrl"
              type="text"
              :placeholder="baseUrlPlaceholder"
              class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
            />
          </div>

          <button
            class="rounded px-3 py-1.5 text-sm font-medium"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
            :disabled="!newProvider.displayName"
            @click="submitAddProvider"
          >
            Add Provider
          </button>

          <span
            v-if="providerStore.error"
            class="ml-2 text-xs"
            style="color: var(--color-risk-red)"
            >{{ providerStore.error }}</span
          >
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from "vue";
import { useProviderStore } from "@/stores/providers";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import ProviderCard from "@/components/settings/ProviderCard.vue";
import type { ProviderType, AuthMethod } from "@/types/provider";

const providerStore = useProviderStore();

const newProvider = ref<{
  providerType: ProviderType;
  displayName: string;
  authMethod: AuthMethod;
  apiKey: string;
  baseUrl: string;
}>({
  providerType: "anthropic",
  displayName: "",
  authMethod: "api_key",
  apiKey: "",
  baseUrl: "",
});

const defaultBaseUrls: Partial<Record<ProviderType, string>> = {
  minimax: "https://api.minimax.io/anthropic",
  ollama: "http://localhost:11434",
  lm_studio: "http://localhost:1234",
};

const baseUrlPlaceholder = computed(
  () =>
    defaultBaseUrls[newProvider.value.providerType] || "http://localhost:11434",
);

watch(
  () => newProvider.value.providerType,
  (type) => {
    if (type in defaultBaseUrls && !newProvider.value.baseUrl) {
      newProvider.value.baseUrl = defaultBaseUrls[type] || "";
    }
  },
);

async function submitAddProvider() {
  if (!newProvider.value.displayName) return;

  await providerStore.addProvider({
    providerType: newProvider.value.providerType,
    displayName: newProvider.value.displayName,
    authMethod: newProvider.value.authMethod,
    apiKey: newProvider.value.apiKey || undefined,
    baseUrl: newProvider.value.baseUrl || null,
  });

  if (!providerStore.error) {
    newProvider.value = {
      providerType: "anthropic",
      displayName: "",
      authMethod: "api_key",
      apiKey: "",
      baseUrl: "",
    };
  }
}

async function submitRemove(id: string) {
  await providerStore.removeProvider(id);
}

onMounted(() => {
  providerStore.fetchProviders();
});
</script>
