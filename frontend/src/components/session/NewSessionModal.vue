<template>
  <Teleport to="body">
    <div
      v-if="open"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/60"
      @click.self="$emit('cancel')"
    >
      <div
        class="w-full max-w-md rounded-xl border p-6"
        style="background: var(--color-navy); border-color: var(--color-border)"
      >
        <h2
          class="mb-4 text-base font-semibold"
          style="color: var(--color-text)"
        >
          New Session
        </h2>

        <!-- Name field (optional) -->
        <div class="mb-4">
          <label
            class="mb-1 block text-xs"
            style="color: var(--color-text-dim)"
          >
            Session name (optional)
          </label>
          <input
            v-model="name"
            type="text"
            placeholder="My Session"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="border-color: var(--color-border); color: var(--color-text)"
          />
        </div>

        <!-- Execution Mode selector -->
        <div class="mb-4">
          <label
            class="mb-1 block text-xs"
            style="color: var(--color-text-dim)"
          >
            Execution mode
          </label>
          <div class="flex gap-2">
            <button
              type="button"
              class="flex-1 rounded border px-3 py-1.5 text-sm transition-colors"
              :style="{
                borderColor:
                  executionMode === 'direct'
                    ? 'var(--color-gold)'
                    : 'var(--color-border)',
                color:
                  executionMode === 'direct'
                    ? 'var(--color-gold)'
                    : 'var(--color-text)',
                background:
                  executionMode === 'direct'
                    ? 'var(--color-surface)'
                    : 'transparent',
              }"
              @click="executionMode = 'direct'"
            >
              Direct
            </button>
            <button
              type="button"
              class="flex-1 rounded border px-3 py-1.5 text-sm transition-colors"
              :style="{
                borderColor:
                  executionMode === 'confirmed'
                    ? 'var(--color-gold)'
                    : 'var(--color-border)',
                color:
                  executionMode === 'confirmed'
                    ? 'var(--color-gold)'
                    : 'var(--color-text)',
                background:
                  executionMode === 'confirmed'
                    ? 'var(--color-surface)'
                    : 'transparent',
              }"
              @click="executionMode = 'confirmed'"
            >
              Confirmed
            </button>
          </div>
        </div>

        <!-- Workspace directories (dynamic list) -->
        <div class="mb-4">
          <label
            class="mb-1 block text-xs"
            style="color: var(--color-text-dim)"
          >
            Workspace folders
          </label>
          <div class="space-y-2">
            <input
              v-for="(dir, idx) in workingDirectories"
              :key="idx"
              v-model="workingDirectories[idx]"
              type="text"
              placeholder="/home/user/project"
              class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
              "
            />
          </div>
          <button
            type="button"
            class="mt-2 text-xs transition-colors hover:text-[var(--color-gold)]"
            style="color: var(--color-text-dim)"
            @click="addFolder"
          >
            + Add folder
          </button>
        </div>

        <!-- Actions -->
        <div class="flex items-center justify-end gap-3">
          <button
            type="button"
            class="text-sm transition-colors hover:text-[var(--color-text)]"
            style="color: var(--color-text-dim)"
            @click="$emit('cancel')"
          >
            Cancel
          </button>
          <button
            type="button"
            class="rounded px-4 py-1.5 text-sm font-medium"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
            @click="handleCreate"
          >
            Create
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import type { ExecutionMode } from "@/types/session";

const props = defineProps<{
  open: boolean;
  projectId?: string | null;
}>();

const emit = defineEmits<{
  (
    e: "create",
    payload: {
      name?: string;
      executionMode: ExecutionMode;
      workingDirectories: string[];
      projectId?: string | null;
    },
  ): void;
  (e: "cancel"): void;
}>();

const name = ref("");
const executionMode = ref<ExecutionMode>("direct");
const workingDirectories = ref<string[]>([""]);

// Reset state when modal opens
watch(
  () => props.open,
  (open) => {
    if (open) {
      name.value = "";
      executionMode.value = "direct";
      workingDirectories.value = [""];
    }
  },
);

function addFolder() {
  workingDirectories.value.push("");
}

function handleCreate() {
  const dirs = workingDirectories.value
    .map((d) => d.trim())
    .filter((d) => d.length > 0);
  emit("create", {
    name: name.value.trim() || undefined,
    executionMode: executionMode.value,
    workingDirectories: dirs,
    projectId: props.projectId,
  });
}
</script>
