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
          <!-- Provider Type -->
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

          <!-- Auth Method — only shown for providers that support choice -->
          <div v-if="!isOAuthOnly">
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
              <option v-if="supportsOAuth" value="oauth">OAuth</option>
            </select>
          </div>

          <!-- Display Name — optional for OAuth, required for API key -->
          <div>
            <label
              class="mb-1 block text-xs font-medium"
              style="color: var(--color-text-dim)"
            >
              Display Name
              <span
                v-if="newProvider.authMethod !== 'oauth'"
                class="ml-1"
                style="color: var(--color-risk-red)"
                >*</span
              >
              <span
                v-else
                class="ml-1 font-normal"
                style="color: var(--color-text-dim)"
                >(optional — auto-filled after OAuth)</span
              >
            </label>
            <input
              v-model="newProvider.displayName"
              type="text"
              :placeholder="
                newProvider.authMethod === 'oauth'
                  ? 'Auto-filled after connecting'
                  : 'e.g. My Anthropic Account'
              "
              class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
            />
          </div>

          <!-- API Key input (only for api_key auth) -->
          <div v-if="newProvider.authMethod === 'api_key'">
            <label
              class="mb-1 block text-xs font-medium"
              style="color: var(--color-text-dim)"
              >API Key
              <span style="color: var(--color-risk-red)">*</span></label
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

          <!-- OAuth info panel -->
          <div
            v-if="newProvider.authMethod === 'oauth'"
            class="rounded border p-3 text-xs"
            style="
              border-color: var(--color-accent-blue);
              background: rgba(122, 158, 194, 0.08);
              color: var(--color-text-dim);
            "
          >
            <p class="mb-1 font-medium" style="color: var(--color-accent-blue)">
              OAuth Connection
            </p>
            <p>
              Clicking <strong>Connect via OAuth</strong> will open a browser
              window to authorize James the Butler. Your tokens will be stored
              securely and refreshed automatically.
            </p>
          </div>

          <!-- Base URL (local / compatible providers) -->
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

          <!-- Action button -->
          <div class="flex items-center gap-3">
            <button
              v-if="newProvider.authMethod !== 'oauth'"
              class="rounded px-3 py-1.5 text-sm font-medium disabled:opacity-50"
              style="
                background: var(--color-gold);
                color: var(--color-navy-deep);
              "
              :disabled="!canSubmit"
              @click="submitAddProvider"
            >
              Add Provider
            </button>

            <button
              v-else
              class="flex items-center gap-2 rounded px-3 py-1.5 text-sm font-medium disabled:opacity-50"
              style="background: var(--color-accent-blue); color: #fff"
              :disabled="oauthPending"
              @click="startOAuthFlow"
            >
              <svg
                v-if="oauthPending"
                xmlns="http://www.w3.org/2000/svg"
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                class="animate-spin"
              >
                <path d="M21 12a9 9 0 1 1-6.219-8.56" />
              </svg>
              <svg
                v-else
                xmlns="http://www.w3.org/2000/svg"
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"
                />
                <polyline points="15 3 21 3 21 9" />
                <line x1="10" y1="14" x2="21" y2="3" />
              </svg>
              {{
                oauthPending
                  ? "Waiting for authorization…"
                  : "Connect via OAuth"
              }}
            </button>

            <span
              v-if="providerStore.error"
              class="text-xs"
              style="color: var(--color-risk-red)"
              >{{ providerStore.error }}</span
            >
          </div>
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

// Providers that only support OAuth (no API key option)
const OAUTH_ONLY_TYPES: ProviderType[] = ["openai_codex"];

// Providers that support OAuth in addition to API key
const OAUTH_SUPPORTED_TYPES: ProviderType[] = ["openai_codex", "openai"];

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

const oauthPending = ref(false);

const isOAuthOnly = computed(() =>
  OAUTH_ONLY_TYPES.includes(newProvider.value.providerType),
);

const supportsOAuth = computed(() =>
  OAUTH_SUPPORTED_TYPES.includes(newProvider.value.providerType),
);

const canSubmit = computed(() => {
  if (newProvider.value.authMethod === "oauth") return true;
  // API key auth: display name and api key both required
  return !!newProvider.value.displayName && !!newProvider.value.apiKey;
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

// Auto-set auth method when provider type changes
watch(
  () => newProvider.value.providerType,
  (type) => {
    if (OAUTH_ONLY_TYPES.includes(type)) {
      newProvider.value.authMethod = "oauth";
    } else if (!OAUTH_SUPPORTED_TYPES.includes(type)) {
      newProvider.value.authMethod = "api_key";
    }
    if (type in defaultBaseUrls && !newProvider.value.baseUrl) {
      newProvider.value.baseUrl = defaultBaseUrls[type] || "";
    }
  },
);

async function startOAuthFlow() {
  oauthPending.value = true;
  try {
    // Request the OAuth authorization URL from the backend
    const data = await providerStore.startOAuthFlow(
      newProvider.value.providerType,
    );
    if (data?.authUrl) {
      // Open in a new tab — the backend will handle the callback and
      // store the tokens; a polling mechanism or WebSocket event will
      // notify us when the flow is complete.
      window.open(data.authUrl, "_blank", "noopener,noreferrer");
      // Poll for completion (simple approach: check every 3 s for up to 5 min)
      await waitForOAuthCompletion(data.stateKey);
    }
  } catch {
    // Error surfaced via providerStore.error
  } finally {
    oauthPending.value = false;
  }
}

async function waitForOAuthCompletion(stateKey: string) {
  const maxAttempts = 100; // 5 minutes at 3 s intervals
  for (let i = 0; i < maxAttempts; i++) {
    await new Promise((r) => setTimeout(r, 3000));
    const completed = await providerStore.pollOAuthCompletion(stateKey);
    if (completed) {
      resetForm();
      return;
    }
  }
}

function resetForm() {
  newProvider.value = {
    providerType: "anthropic",
    displayName: "",
    authMethod: "api_key",
    apiKey: "",
    baseUrl: "",
  };
}

async function submitAddProvider() {
  if (!canSubmit.value) return;

  await providerStore.addProvider({
    providerType: newProvider.value.providerType,
    displayName: newProvider.value.displayName,
    authMethod: newProvider.value.authMethod,
    apiKey: newProvider.value.apiKey || undefined,
    baseUrl: newProvider.value.baseUrl || null,
  });

  if (!providerStore.error) {
    resetForm();
  }
}

async function submitRemove(id: string) {
  await providerStore.removeProvider(id);
}

onMounted(() => {
  providerStore.fetchProviders();
});
</script>
