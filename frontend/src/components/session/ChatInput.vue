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
      <!-- Textarea — always enabled; parent queues messages while James responds -->
      <textarea
        ref="inputRef"
        v-model="text"
        placeholder="How can James help you today?"
        rows="3"
        class="block w-full resize-none bg-transparent px-4 pt-3 pb-10 text-sm outline-none"
        style="color: var(--color-text); min-height: 120px"
        @focus="focused = true"
        @blur="focused = false"
        @input="autoResize"
        @keydown.enter.exact.prevent="submit"
      />

      <!-- Bottom toolbar row -->
      <div
        class="absolute bottom-0 left-0 right-0 flex items-center justify-between px-2 pb-2"
      >
        <!-- Left: + button -->
        <div ref="plusMenuWrapRef" class="relative">
          <button
            type="button"
            class="flex h-8 w-8 items-center justify-center rounded-lg transition-colors hover:bg-[var(--color-navy)]"
            style="color: var(--color-text-dim)"
            @click.stop="
              showPlusMenu = !showPlusMenu;
              showModelMenu = false;
              showProviderMenu = false;
            "
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
            @click.stop
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

        <!-- Right: provider selector + model selector + send -->
        <div class="flex items-center gap-2">
          <!-- Provider selector -->
          <div ref="providerMenuWrapRef" class="relative">
            <button
              type="button"
              class="flex items-center gap-1 rounded-lg px-2 py-1 text-xs transition-colors hover:bg-[var(--color-navy)]"
              style="color: var(--color-text-dim)"
              @click.stop="
                showProviderMenu = !showProviderMenu;
                showModelMenu = false;
                showPlusMenu = false;
              "
            >
              <span
                v-if="activeProvider"
                class="mr-0.5 inline-block h-1.5 w-1.5 rounded-full"
                :class="providerStatusDot"
              />
              {{ activeProvider?.displayName ?? "No provider" }}
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

            <!-- Provider dropdown -->
            <div
              v-if="showProviderMenu"
              class="absolute bottom-8 right-0 z-50 w-44 rounded-xl border py-2 shadow-xl"
              style="
                background: var(--color-navy);
                border-color: var(--color-border);
              "
              @click.stop
            >
              <div
                v-if="providerStore.providers.length === 0"
                class="px-4 py-3 text-xs"
                style="color: var(--color-text-dim)"
              >
                No providers.
                <RouterLink
                  to="/settings/models"
                  class="underline"
                  style="color: var(--color-gold)"
                  @click="showProviderMenu = false"
                >
                  Add in Settings
                </RouterLink>
              </div>
              <button
                v-for="provider in providerStore.providers"
                :key="provider.id"
                class="flex w-full items-center justify-between px-4 py-1.5 text-sm transition-colors hover:bg-[var(--color-surface)]"
                :style="{
                  color:
                    activeProviderId === provider.id
                      ? 'var(--color-accent-blue)'
                      : 'var(--color-text)',
                }"
                @click="selectProvider(provider.id)"
              >
                <span class="flex items-center gap-1.5">
                  <span
                    class="inline-block h-1.5 w-1.5 rounded-full"
                    :class="dotForStatus(provider.status)"
                  />
                  {{ provider.displayName }}
                </span>
                <svg
                  v-if="activeProviderId === provider.id"
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

          <!-- Model selector -->
          <div ref="modelMenuWrapRef" class="relative">
            <button
              type="button"
              class="flex items-center gap-1 rounded-lg px-2 py-1 text-xs transition-colors hover:bg-[var(--color-navy)]"
              style="color: var(--color-text-dim)"
              @click.stop="
                showModelMenu = !showModelMenu;
                showProviderMenu = false;
                showPlusMenu = false;
              "
            >
              {{ activeModelId || "Model" }}
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
              class="absolute bottom-8 right-0 z-50 w-52 rounded-xl border py-2 shadow-xl"
              style="
                background: var(--color-navy);
                border-color: var(--color-border);
              "
              @click.stop
            >
              <div
                v-if="!activeProvider"
                class="px-4 py-3 text-xs"
                style="color: var(--color-text-dim)"
              >
                Select a provider first
              </div>
              <template v-else-if="activeProvider.models?.length">
                <button
                  v-for="model in activeProvider.models"
                  :key="model"
                  class="flex w-full items-center justify-between px-4 py-1.5 text-sm transition-colors hover:bg-[var(--color-surface)]"
                  :style="{
                    color:
                      activeModelId === model
                        ? 'var(--color-accent-blue)'
                        : 'var(--color-text)',
                  }"
                  @click="selectModelOnly(model)"
                >
                  {{ model }}
                  <svg
                    v-if="activeModelId === model"
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
              </template>
              <div
                v-else
                class="px-4 py-3 text-xs"
                style="color: var(--color-text-dim)"
              >
                No models for this provider
              </div>
            </div>
          </div>

          <!-- Send button -->
          <button
            type="button"
            :disabled="!text.trim()"
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
import { ref, computed, watchEffect, onMounted, onUnmounted } from "vue";
import { RouterLink } from "vue-router";
import MenuItemWithSubmenu from "./MenuItemWithSubmenu.vue";
import { useProviderStore } from "@/stores/providers";

// No `disabled` prop — SessionView queues messages while James is responding.
const emit = defineEmits<{ send: [text: string] }>();

const providerStore = useProviderStore();

const text = ref("");
const focused = ref(false);
const inputRef = ref<HTMLTextAreaElement | null>(null);
const plusMenuWrapRef = ref<HTMLElement | null>(null);
const modelMenuWrapRef = ref<HTMLElement | null>(null);
const providerMenuWrapRef = ref<HTMLElement | null>(null);
const showPlusMenu = ref(false);
const showModelMenu = ref(false);
const showProviderMenu = ref(false);
const webSearchEnabled = ref(false);
const activeStyle = ref("normal");

// Active provider / model selection (defaults to first connected provider)
const activeProviderId = ref<string | null>(null);
const activeModelId = ref<string>("");

const activeProvider = computed(
  () =>
    providerStore.providers.find((p) => p.id === activeProviderId.value) ??
    providerStore.providers.find((p) => p.status === "connected") ??
    providerStore.providers[0] ??
    null,
);

// Keep activeProviderId in sync when providers load / change.
// watchEffect (not computed) because this intentionally writes reactive state.
watchEffect(() => {
  if (!activeProviderId.value && activeProvider.value) {
    activeProviderId.value = activeProvider.value.id;
    activeModelId.value = activeProvider.value.models?.[0] ?? "";
  }
});

function dotForStatus(status: string): string {
  if (status === "connected") return "bg-green-500";
  if (status === "failed") return "bg-red-500";
  return "bg-yellow-400";
}

const providerStatusDot = computed(() =>
  dotForStatus(activeProvider.value?.status ?? "untested"),
);

const styles = [
  { id: "normal", label: "Normal" },
  { id: "concise", label: "Concise" },
  { id: "explanatory", label: "Explanatory" },
  { id: "formal", label: "Formal" },
  { id: "butler", label: "Butler" },
];

function submit() {
  const t = text.value.trim();
  if (!t) return;
  emit("send", t);
  text.value = "";
  if (inputRef.value) {
    inputRef.value.style.height = "120px";
    inputRef.value.style.overflowY = "hidden";
  }
}

function autoResize() {
  const el = inputRef.value;
  if (!el) return;
  // Reset to min-height first so scrollHeight reports natural content height
  el.style.height = "120px";
  el.style.overflowY = "hidden";
  const maxH = Math.floor(window.innerHeight * 0.5);
  if (el.scrollHeight > maxH) {
    el.style.height = maxH + "px";
    el.style.overflowY = "auto";
  } else {
    el.style.height = el.scrollHeight + "px";
  }
}

function handleMenuAction(action: string) {
  showPlusMenu.value = false;
  if (action === "dream") {
    text.value = "/dream";
  }
  // files: TODO file picker
}

function toggleWebSearch() {
  webSearchEnabled.value = !webSearchEnabled.value;
}

function setStyle(id: string) {
  activeStyle.value = id;
}

function selectProvider(providerId: string) {
  activeProviderId.value = providerId;
  // Clear model if it's not in the new provider's model list
  const provider = providerStore.providers.find((p) => p.id === providerId);
  if (
    provider &&
    provider.models &&
    !provider.models.includes(activeModelId.value)
  ) {
    activeModelId.value = provider.models[0] ?? "";
  }
  showProviderMenu.value = false;
}

function selectModelOnly(model: string) {
  activeModelId.value = model;
  showModelMenu.value = false;
}

/** Keep for backward compat — selects both provider and model at once. */
function _selectModel(providerId: string, model: string) {
  activeProviderId.value = providerId;
  activeModelId.value = model;
  showModelMenu.value = false;
}

// ── Outside-click handler ────────────────────────────────────────────────────
function handleOutsideClick(e: MouseEvent) {
  const target = e.target as Node;
  if (plusMenuWrapRef.value && !plusMenuWrapRef.value.contains(target)) {
    showPlusMenu.value = false;
  }
  if (modelMenuWrapRef.value && !modelMenuWrapRef.value.contains(target)) {
    showModelMenu.value = false;
  }
  if (
    providerMenuWrapRef.value &&
    !providerMenuWrapRef.value.contains(target)
  ) {
    showProviderMenu.value = false;
  }
}

onMounted(() => {
  inputRef.value?.focus();
  document.addEventListener("click", handleOutsideClick);
});

onUnmounted(() => {
  document.removeEventListener("click", handleOutsideClick);
});
</script>
