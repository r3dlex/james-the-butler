<template>
  <div
    class="rounded border p-4"
    style="
      border-color: var(--color-border);
      background: var(--color-navy-deep);
    "
  >
    <!-- Header row: status dot, name, buttons -->
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
        <span class="text-xs" style="color: var(--color-text-dim)"
          >({{ provider.providerType }})</span
        >
      </div>
      <div class="flex items-center gap-2">
        <button
          class="rounded px-2 py-1 text-xs font-medium"
          style="
            border: 1px solid var(--color-border);
            color: var(--color-text-dim);
          "
          :disabled="testing"
          data-testid="test-btn"
          @click="onTestConnection"
        >
          <span v-if="testing">...</span>
          <span v-else>Test Connection</span>
        </button>
        <button
          v-if="!editing"
          class="rounded px-2 py-1 text-xs font-medium"
          style="background: var(--color-gold); color: var(--color-navy-deep)"
          @click="startEditing"
        >
          Configure
        </button>
      </div>
    </div>

    <!-- Inline edit form (expanded) -->
    <div
      v-if="editing"
      class="mt-3 space-y-3 border-t pt-3"
      style="border-color: var(--color-border)"
    >
      <div>
        <label
          class="mb-1 block text-xs font-medium"
          style="color: var(--color-text-dim)"
          >Display Name</label
        >
        <input
          v-model="editForm.displayName"
          type="text"
          class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
          style="
            border-color: var(--color-border);
            color: var(--color-text);
            background: var(--color-navy-deep);
          "
        />
      </div>

      <div v-if="provider.authMethod === 'api_key'">
        <label
          class="mb-1 block text-xs font-medium"
          style="color: var(--color-text-dim)"
          >API Key</label
        >
        <input
          v-model="editForm.apiKey"
          type="password"
          :placeholder="provider.apiKeyMasked || provider.apiKey || 'sk-...'"
          class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
          style="
            border-color: var(--color-border);
            color: var(--color-text);
            background: var(--color-navy-deep);
          "
        />
        <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">
          Leave blank to keep current key
        </p>
      </div>

      <div v-if="showBaseUrl">
        <label
          class="mb-1 block text-xs font-medium"
          style="color: var(--color-text-dim)"
          >Base URL</label
        >
        <input
          v-model="editForm.baseUrl"
          type="text"
          class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
          style="
            border-color: var(--color-border);
            color: var(--color-text);
            background: var(--color-navy-deep);
          "
        />
      </div>

      <div class="flex gap-2">
        <button
          class="rounded px-3 py-1.5 text-sm font-medium"
          style="background: var(--color-gold); color: var(--color-navy-deep)"
          @click="submitUpdate"
        >
          Save
        </button>
        <button
          class="rounded px-3 py-1.5 text-sm font-medium"
          style="
            border: 1px solid var(--color-border);
            color: var(--color-text-dim);
          "
          @click="cancelEditing"
        >
          Cancel
        </button>
        <button
          class="ml-auto rounded px-3 py-1.5 text-sm font-medium"
          style="color: var(--color-risk-red)"
          @click="$emit('remove', provider.id)"
        >
          Remove
        </button>
      </div>
    </div>

    <!-- Models list (when not editing) -->
    <div
      v-if="!editing && provider.models && provider.models.length > 0"
      class="mt-3"
    >
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
    <div
      v-else-if="!editing"
      class="mt-2 text-xs"
      style="color: var(--color-text-dim)"
    >
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
  remove: [id: string];
}>();

const providerStore = useProviderStore();
const testing = ref(false);
const editing = ref(false);

const editForm = ref({
  displayName: "",
  apiKey: "",
  baseUrl: "",
});

const providersNeedingBaseUrl = [
  "ollama",
  "lm_studio",
  "openai_compatible",
  "minimax",
];

const showBaseUrl = computed(() =>
  providersNeedingBaseUrl.includes(props.provider.providerType),
);

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

function startEditing() {
  editForm.value = {
    displayName: props.provider.displayName,
    apiKey: "",
    baseUrl: props.provider.baseUrl || "",
  };
  editing.value = true;
}

function cancelEditing() {
  editing.value = false;
}

async function submitUpdate() {
  const updates: Record<string, string> = {};
  if (editForm.value.displayName !== props.provider.displayName) {
    updates.displayName = editForm.value.displayName;
  }
  if (editForm.value.apiKey) {
    updates.apiKey = editForm.value.apiKey;
  }
  if (editForm.value.baseUrl !== (props.provider.baseUrl || "")) {
    updates.baseUrl = editForm.value.baseUrl;
  }
  if (Object.keys(updates).length > 0) {
    await providerStore.updateProvider(props.provider.id, updates);
  }
  if (!providerStore.error) {
    editing.value = false;
  }
}

async function onTestConnection() {
  testing.value = true;
  try {
    await providerStore.testConnection(props.provider.id);
  } finally {
    testing.value = false;
  }
}
</script>
