<template>
  <div class="p-6">
    <h1 class="mb-1 text-lg font-medium" style="color: var(--color-text)">
      General
    </h1>
    <p class="mb-6 text-sm" style="color: var(--color-text-dim)">
      Global preferences for James the Butler.
    </p>

    <div class="max-w-lg space-y-8">
      <!-- Appearance -->
      <section>
        <h2
          class="mb-3 text-xs font-semibold uppercase tracking-wider"
          style="color: var(--color-text-dim)"
        >
          Appearance
        </h2>
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium" style="color: var(--color-text)">
                Theme
              </p>
              <p class="text-xs" style="color: var(--color-text-dim)">
                Choose your colour scheme.
              </p>
            </div>
            <select
              v-model="settings.theme"
              class="rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
              @change="save"
            >
              <option value="dark">Dark</option>
              <option value="light">Light</option>
              <option value="system">System</option>
            </select>
          </div>
        </div>
      </section>

      <div class="h-px" style="background: var(--color-border)" />

      <!-- Sessions -->
      <section>
        <h2
          class="mb-3 text-xs font-semibold uppercase tracking-wider"
          style="color: var(--color-text-dim)"
        >
          Sessions
        </h2>
        <div class="space-y-4">
          <!-- Default execution mode -->
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium" style="color: var(--color-text)">
                Default execution mode
              </p>
              <p class="text-xs" style="color: var(--color-text-dim)">
                How new sessions run actions by default.
              </p>
            </div>
            <select
              v-model="settings.defaultExecutionMode"
              class="rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
              @change="save"
            >
              <option value="direct">Direct (auto-approve)</option>
              <option value="supervised">Supervised (manual approve)</option>
            </select>
          </div>

          <!-- Keep intermediates -->
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="text-sm font-medium" style="color: var(--color-text)">
                Keep intermediate steps
              </p>
              <p class="text-xs" style="color: var(--color-text-dim)">
                Retain tool-call and reasoning messages in the chat view.
              </p>
            </div>
            <button
              type="button"
              role="switch"
              :aria-checked="settings.keepIntermediates"
              class="relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors"
              :style="{
                background: settings.keepIntermediates
                  ? 'var(--color-gold)'
                  : 'var(--color-border)',
              }"
              @click="settings.keepIntermediates = !settings.keepIntermediates; save()"
            >
              <span
                class="pointer-events-none inline-block h-4 w-4 transform rounded-full shadow-sm transition-transform"
                style="background: var(--color-navy-deep)"
                :class="settings.keepIntermediates ? 'translate-x-4' : 'translate-x-0'"
              />
            </button>
          </div>
        </div>
      </section>

      <div class="h-px" style="background: var(--color-border)" />

      <!-- About -->
      <section>
        <h2
          class="mb-3 text-xs font-semibold uppercase tracking-wider"
          style="color: var(--color-text-dim)"
        >
          About
        </h2>
        <p class="text-xs" style="color: var(--color-text-dim)">
          James the Butler — v0.1.0
        </p>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive, onMounted } from "vue";

const STORAGE_KEY = "james_general_settings";

interface GeneralSettings {
  theme: "dark" | "light" | "system";
  defaultExecutionMode: "direct" | "supervised";
  keepIntermediates: boolean;
}

const defaults: GeneralSettings = {
  theme: "dark",
  defaultExecutionMode: "direct",
  keepIntermediates: false,
};

const settings = reactive<GeneralSettings>({ ...defaults });

function save() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
}

onMounted(() => {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) Object.assign(settings, JSON.parse(stored));
  } catch {
    // ignore corrupt storage
  }
});
</script>
