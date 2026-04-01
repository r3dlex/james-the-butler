<template>
  <div class="border-t px-4 py-3" style="border-color: var(--color-border)">
    <!-- Input container — rounded card style like Claude -->
    <div
      class="relative rounded-2xl border transition-colors"
      :class="focused ? 'border-[var(--color-gold)]' : ''"
      style="
        background: var(--color-surface);
        border-color: var(--color-border);
      "
    >
      <!-- Textarea -->
      <textarea
        ref="inputRef"
        v-model="text"
        :placeholder="
          disabled ? 'Waiting for response...' : 'How can James help you today?'
        "
        :disabled="disabled"
        rows="1"
        class="block w-full resize-none bg-transparent px-4 pt-3 pb-10 text-sm outline-none"
        style="color: var(--color-text); min-height: 44px; max-height: 200px"
        @focus="focused = true"
        @blur="focused = false"
        @input="autoResize"
        @keydown.enter.exact="submit"
      />

      <!-- Bottom toolbar row -->
      <div
        class="absolute bottom-0 left-0 right-0 flex items-center justify-between px-2 pb-2"
      >
        <!-- Left: + button -->
        <div class="relative">
          <button
            type="button"
            class="flex h-8 w-8 items-center justify-center rounded-lg transition-colors hover:bg-[var(--color-navy)]"
            style="color: var(--color-text-dim)"
            @click="showPlusMenu = !showPlusMenu"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="M5 12h14" />
              <path d="M12 5v14" />
            </svg>
          </button>

          <!-- + Menu Popover -->
          <div
            v-if="showPlusMenu"
            class="absolute bottom-10 left-0 z-50 w-56 rounded-xl border py-2 shadow-xl"
            style="
              background: var(--color-navy);
              border-color: var(--color-border);
            "
          >
            <button
              class="flex w-full items-center gap-3 px-4 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
              style="color: var(--color-text)"
              @click="handleMenuAction('files')"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path
                  d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48"
                />
              </svg>
              Add files or photos
            </button>

            <div class="my-1 h-px" style="background: var(--color-border)" />

            <MenuItemWithSubmenu label="Skills" icon="skills">
              <button
                class="flex w-full items-center gap-3 px-4 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
                style="color: var(--color-text)"
                @click="handleMenuAction('dream')"
              >
                /dream
              </button>
            </MenuItemWithSubmenu>

            <MenuItemWithSubmenu label="Connectors" icon="connectors">
              <button
                class="flex w-full items-center gap-3 px-4 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
                style="color: var(--color-text-dim)"
              >
                No connectors configured
              </button>
            </MenuItemWithSubmenu>

            <div class="my-1 h-px" style="background: var(--color-border)" />

            <button
              class="flex w-full items-center gap-3 px-4 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
              style="color: var(--color-text)"
              :style="{
                color: webSearchEnabled
                  ? 'var(--color-risk-green)'
                  : 'var(--color-text)',
              }"
              @click="toggleWebSearch"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <circle cx="12" cy="12" r="10" />
                <path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20" />
                <path d="M2 12h20" />
              </svg>
              Web search
              <svg
                v-if="webSearchEnabled"
                xmlns="http://www.w3.org/2000/svg"
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="3"
                class="ml-auto"
              >
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </button>

            <MenuItemWithSubmenu label="Use style" icon="style">
              <button
                v-for="style in styles"
                :key="style.id"
                class="flex w-full items-center gap-3 px-4 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
                :style="{
                  color:
                    activeStyle === style.id
                      ? 'var(--color-accent-blue)'
                      : 'var(--color-text)',
                }"
                @click="setStyle(style.id)"
              >
                {{ style.label }}
                <svg
                  v-if="activeStyle === style.id"
                  xmlns="http://www.w3.org/2000/svg"
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                  class="ml-auto"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              </button>
              <div class="my-1 h-px" style="background: var(--color-border)" />
              <button
                class="flex w-full items-center gap-3 px-4 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
                style="color: var(--color-text-dim)"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path d="M5 12h14" />
                  <path d="M12 5v14" />
                </svg>
                Create &amp; edit styles
              </button>
            </MenuItemWithSubmenu>
          </div>
        </div>

        <!-- Right: model selector + send -->
        <div class="flex items-center gap-2">
          <!-- Model selector -->
          <div class="relative">
            <button
              type="button"
              class="flex items-center gap-1 rounded-lg px-2 py-1 text-xs transition-colors hover:bg-[var(--color-navy)]"
              style="color: var(--color-text-dim)"
              @click="showModelMenu = !showModelMenu"
            >
              {{ activeModelLabel }}
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="12"
                height="12"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path d="m6 9 6 6 6-6" />
              </svg>
            </button>

            <!-- Model dropdown -->
            <div
              v-if="showModelMenu"
              class="absolute bottom-8 right-0 z-50 w-48 rounded-xl border py-2 shadow-xl"
              style="
                background: var(--color-navy);
                border-color: var(--color-border);
              "
            >
              <button
                v-for="model in models"
                :key="model.id"
                class="flex w-full items-center justify-between px-4 py-2 text-sm transition-colors hover:bg-[var(--color-surface)]"
                :style="{
                  color:
                    activeModel === model.id
                      ? 'var(--color-accent-blue)'
                      : 'var(--color-text)',
                }"
                @click="selectModel(model.id)"
              >
                {{ model.label }}
                <svg
                  v-if="activeModel === model.id"
                  xmlns="http://www.w3.org/2000/svg"
                  width="14"
                  height="14"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
              </button>
            </div>
          </div>

          <!-- Send button -->
          <button
            type="button"
            :disabled="disabled || !text.trim()"
            class="flex h-8 w-8 items-center justify-center rounded-full transition-opacity disabled:cursor-not-allowed disabled:opacity-30"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
            @click="submit"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path d="m5 12 7-7 7 7" />
              <path d="M12 19V5" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import MenuItemWithSubmenu from "./MenuItemWithSubmenu.vue";

defineProps<{ disabled?: boolean }>();
const emit = defineEmits<{ send: [text: string] }>();

const text = ref("");
const focused = ref(false);
const inputRef = ref<HTMLTextAreaElement | null>(null);
const showPlusMenu = ref(false);
const showModelMenu = ref(false);
const webSearchEnabled = ref(false);
const activeStyle = ref("normal");
const activeModel = ref("minimax-m2.7");

const models = [
  { id: "minimax-m2.7", label: "MiniMax M2.7" },
  { id: "claude-sonnet-4", label: "Claude Sonnet 4" },
  { id: "claude-opus-4", label: "Claude Opus 4" },
  { id: "gpt-4o", label: "GPT-4o" },
  { id: "local", label: "Local Model" },
];

const styles = [
  { id: "normal", label: "Normal" },
  { id: "concise", label: "Concise" },
  { id: "explanatory", label: "Explanatory" },
  { id: "formal", label: "Formal" },
  { id: "butler", label: "Butler" },
];

const activeModelLabel = computed(
  () => models.find((m) => m.id === activeModel.value)?.label ?? "Model",
);

function submit() {
  const t = text.value.trim();
  if (!t) return;
  emit("send", t);
  text.value = "";
  // Reset textarea height
  if (inputRef.value) inputRef.value.style.height = "44px";
}

function autoResize() {
  const el = inputRef.value;
  if (!el) return;
  el.style.height = "44px";
  el.style.height = Math.min(el.scrollHeight, 200) + "px";
}

function handleMenuAction(action: string) {
  showPlusMenu.value = false;
  if (action === "files") {
    // TODO: file picker
  } else if (action === "dream") {
    text.value = "/dream";
  }
}

function toggleWebSearch() {
  webSearchEnabled.value = !webSearchEnabled.value;
}

function setStyle(id: string) {
  activeStyle.value = id;
}

function selectModel(id: string) {
  activeModel.value = id;
  showModelMenu.value = false;
}

onMounted(() => {
  inputRef.value?.focus();

  // Close menus on outside click
  document.addEventListener("click", (e) => {
    const target = e.target as HTMLElement;
    if (!target.closest("[data-menu]") && !target.closest("button")) {
      showPlusMenu.value = false;
      showModelMenu.value = false;
    }
  });
});
</script>
