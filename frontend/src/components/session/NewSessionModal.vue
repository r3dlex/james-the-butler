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
            placeholder="Leave blank for a generated name"
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
          <select
            v-model="executionModeChoice"
            class="w-full rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
            style="
              border-color: var(--color-border);
              color: var(--color-text);
              background: var(--color-navy-deep);
            "
          >
            <option value="user_default">User Default</option>
            <option value="direct">Direct</option>
            <option value="confirmed">Supervised</option>
          </select>
        </div>

        <!-- Workspace directories -->
        <div class="mb-4">
          <label
            class="mb-1 block text-xs"
            style="color: var(--color-text-dim)"
          >
            Workspace folders
          </label>

          <!-- Selected folders as chips -->
          <div v-if="workingDirectories.length > 0" class="mb-2 space-y-1">
            <div
              v-for="(dir, idx) in workingDirectories"
              :key="idx"
              class="flex items-center gap-2 rounded border px-2 py-1"
              style="border-color: var(--color-border)"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="12"
                height="12"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                class="shrink-0"
                style="color: var(--color-text-dim)"
              >
                <path
                  d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"
                />
              </svg>
              <span
                class="min-w-0 flex-1 truncate text-xs"
                style="color: var(--color-text)"
                :title="dir"
              >
                {{ dir }}
              </span>
              <button
                type="button"
                class="shrink-0 text-xs transition-colors hover:text-[var(--color-risk-red)]"
                style="color: var(--color-text-dim)"
                :aria-label="`Remove ${dir}`"
                @click="removeFolder(idx)"
              >
                ×
              </button>
            </div>
          </div>

          <!-- Hidden file input for native folder picker -->
          <input
            ref="folderPickerRef"
            type="file"
            style="display: none"
            @change="onFolderSelected"
          />

          <button
            type="button"
            class="mt-1 text-xs transition-colors hover:text-[var(--color-gold)]"
            style="color: var(--color-text-dim)"
            @click="openFolderPicker"
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

const SETTINGS_KEY = "james_general_settings";

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

type ExecutionModeChoice = ExecutionMode | "user_default";

const name = ref("");
const executionModeChoice = ref<ExecutionModeChoice>("user_default");
const workingDirectories = ref<string[]>([]);
const folderPickerRef = ref<HTMLInputElement | null>(null);

// Reset state when modal opens
watch(
  () => props.open,
  (open) => {
    if (open) {
      name.value = "";
      executionModeChoice.value = "user_default";
      workingDirectories.value = [];
    }
  },
);

function openFolderPicker() {
  folderPickerRef.value?.click();
}

function onFolderSelected(event: Event) {
  const input = event.target as HTMLInputElement;
  const files = input.files;
  if (!files || files.length === 0) return;

  // Extract folder path from the selected files.
  // In Tauri/Electron contexts file.path is available (absolute path).
  // In web browsers we get the webkitRelativePath (relative).
  const firstFile = files[0];
  const folderPath =
    (firstFile as unknown as { path?: string }).path ||
    (firstFile.webkitRelativePath
      ? firstFile.webkitRelativePath.split("/")[0]
      : firstFile.name);

  if (folderPath && !workingDirectories.value.includes(folderPath)) {
    workingDirectories.value.push(folderPath);
  }

  // Reset so the same folder can be re-selected if needed
  input.value = "";
}

function removeFolder(idx: number) {
  workingDirectories.value.splice(idx, 1);
}

/** Resolve "user_default" → the persisted setting value. */
function resolveExecutionMode(): ExecutionMode {
  if (executionModeChoice.value !== "user_default") {
    return executionModeChoice.value as ExecutionMode;
  }
  try {
    const stored = localStorage.getItem(SETTINGS_KEY);
    if (stored) {
      const settings = JSON.parse(stored) as { defaultExecutionMode?: string };
      const mode = settings.defaultExecutionMode;
      // Settings stores "supervised"; sessions type uses "confirmed"
      if (mode === "supervised") return "confirmed";
      if (mode === "direct") return "direct";
    }
  } catch {
    // ignore corrupt storage
  }
  return "direct";
}

function handleCreate() {
  emit("create", {
    name: name.value.trim() || undefined,
    executionMode: resolveExecutionMode(),
    workingDirectories: [...workingDirectories.value],
    projectId: props.projectId,
  });
}
</script>
