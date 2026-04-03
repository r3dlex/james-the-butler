<template>
  <div class="folder-path-input">
    <label
      v-if="showLabel"
      class="mb-1 block text-xs"
      style="color: var(--color-text-dim)"
    >
      {{ label }}
    </label>
    <div class="flex items-center gap-2">
      <input
        ref="textInputRef"
        v-model="pathDraft"
        type="text"
        :placeholder="placeholder"
        class="min-w-0 flex-1 rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
        style="border-color: var(--color-border); color: var(--color-text)"
        @keydown.enter.prevent="submitPath"
      />
      <!-- Browse button only shown on Tauri desktop; web browsers get real path from text input -->
      <button
        v-if="isDesktop"
        type="button"
        class="shrink-0 rounded border px-2 py-1.5 text-xs transition-colors hover:border-[var(--color-gold)] hover:text-[var(--color-gold)]"
        style="border-color: var(--color-border); color: var(--color-text-dim)"
        @click="openBrowse"
      >
        Browse
      </button>
    </div>
    <!-- Hidden webkitdirectory input for native folder browsing (Tauri desktop only) -->
    <input
      v-if="isDesktop"
      ref="fileInputRef"
      type="file"
      webkitdirectory
      style="display: none"
      @change="onFileInputChange"
    />
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { usePlatform } from "@/composables/usePlatform";

withDefaults(
  defineProps<{
    label?: string;
    placeholder?: string;
    showLabel?: boolean;
  }>(),
  {
    label: "Folder Path",
    placeholder: "/path/to/folder",
    showLabel: true,
  },
);

const emit = defineEmits<{
  select: [path: string];
}>();

const { isDesktop } = usePlatform();

const textInputRef = ref<HTMLInputElement | null>(null);
const fileInputRef = ref<HTMLInputElement | null>(null);
const pathDraft = ref("");

function submitPath() {
  const path = pathDraft.value.trim();
  if (path) {
    emit("select", path);
    pathDraft.value = "";
  }
}

function openBrowse() {
  if (isDesktop.value) {
    // On Tauri desktop: use the hidden webkitdirectory input to open native dialog.
    // The file.path property returned by Tauri contains the real absolute path.
    fileInputRef.value?.click();
  }
}

function onFileInputChange(event: Event) {
  const input = event.target as HTMLInputElement;
  const files = input.files;
  if (!files || files.length === 0) return;

  const firstFile = files[0];
  // In Tauri contexts file.path is available (absolute path).
  const folderPath =
    (firstFile as unknown as { path?: string }).path ||
    (firstFile.webkitRelativePath
      ? firstFile.webkitRelativePath.split("/")[0]
      : firstFile.name);

  if (folderPath) {
    pathDraft.value = folderPath;
    emit("select", folderPath);
  }

  // Reset so the same folder can be re-selected if needed
  input.value = "";
}
</script>
