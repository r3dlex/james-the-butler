<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">Hooks</h1>
      <button
        class="rounded px-3 py-1.5 text-sm font-medium"
        style="background: var(--color-gold); color: var(--color-navy-deep)"
        @click="showCreate = true"
      >
        Add Hook
      </button>
    </div>

    <div v-if="showCreate" class="mb-4 rounded-md border p-4 space-y-3" style="border-color: var(--color-border)">
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)">Event</label>
          <select v-model="newEvent" class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none" style="border-color: var(--color-border); color: var(--color-text); background: var(--color-navy-deep)">
            <option v-for="e in events" :key="e" :value="e">{{ e }}</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-xs" style="color: var(--color-text-dim)">Type</label>
          <select v-model="newType" class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none" style="border-color: var(--color-border); color: var(--color-text); background: var(--color-navy-deep)">
            <option value="command">Command</option>
            <option value="http">HTTP Webhook</option>
            <option value="prompt">Prompt</option>
            <option value="agent">Agent</option>
          </select>
        </div>
      </div>
      <div>
        <label class="mb-1 block text-xs" style="color: var(--color-text-dim)">Matcher (pipe-separated tool names, optional)</label>
        <input v-model="newMatcher" type="text" class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none" style="border-color: var(--color-border); color: var(--color-text)" placeholder="tool_a|tool_b" />
      </div>
      <div class="flex gap-2">
        <button class="rounded px-3 py-1.5 text-sm font-medium" style="background: var(--color-gold); color: var(--color-navy-deep)" @click="createHook">Create</button>
        <button class="text-sm" style="color: var(--color-text-dim)" @click="showCreate = false">Cancel</button>
      </div>
    </div>

    <LoadingSpinner v-if="loading" />

    <EmptyState v-else-if="hooks.length === 0" message="No hooks configured. Hooks let you run commands or webhooks in response to agent events." />

    <div v-else class="space-y-2">
      <div v-for="hook in hooks" :key="hook.id" class="flex items-center justify-between rounded-md border p-3" style="border-color: var(--color-border)">
        <div>
          <p class="text-sm font-medium" style="color: var(--color-text)">{{ hook.event }}</p>
          <p class="mt-0.5 text-xs" style="color: var(--color-text-dim)">{{ hook.type }} · {{ hook.scope }}{{ hook.matcher ? ` · ${hook.matcher}` : "" }}</p>
        </div>
        <button class="text-xs" style="color: var(--color-risk-red)" @click="deleteHook(hook)">Delete</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

interface Hook {
  id: string;
  event: string;
  type: string;
  scope: string;
  matcher: string | null;
  enabled: boolean;
}

const hooks = ref<Hook[]>([]);
const loading = ref(false);
const showCreate = ref(false);
const newEvent = ref("task_start");
const newType = ref("command");
const newMatcher = ref("");

const events = [
  "session_start", "session_end", "session_suspend",
  "pre_tool_use", "post_tool_use", "pre_prompt_submit",
  "task_start", "task_complete", "task_failed",
  "memory_extracted", "config_change",
  "checkpoint_created", "rewind_executed",
];

async function fetchHooks() {
  loading.value = true;
  try {
    const data = await api.get<{ hooks: Hook[] }>("/api/hooks");
    hooks.value = data.hooks;
  } catch {
    hooks.value = [];
  } finally {
    loading.value = false;
  }
}

async function createHook() {
  try {
    const data = await api.post<{ hook: Hook }>("/api/hooks", {
      event: newEvent.value,
      type: newType.value,
      matcher: newMatcher.value || null,
    });
    hooks.value.push(data.hook);
    showCreate.value = false;
    newMatcher.value = "";
  } catch { /* */ }
}

async function deleteHook(hook: Hook) {
  try {
    await api.delete(`/api/hooks/${hook.id}`);
    hooks.value = hooks.value.filter((h) => h.id !== hook.id);
  } catch { /* */ }
}

onMounted(fetchHooks);
</script>
