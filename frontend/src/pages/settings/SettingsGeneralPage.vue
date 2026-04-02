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
              @change="onThemeChange"
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
              @click="
                settings.keepIntermediates = !settings.keepIntermediates;
                save();
              "
            >
              <span
                class="pointer-events-none inline-block h-4 w-4 transform rounded-full shadow-sm transition-transform"
                style="background: var(--color-navy-deep)"
                :class="
                  settings.keepIntermediates ? 'translate-x-4' : 'translate-x-0'
                "
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
        <div class="space-y-3">
          <div class="flex items-center gap-3">
            <img :src="logoSrc" alt="James the Butler" width="36" height="36" />
            <div>
              <p
                class="text-sm font-semibold"
                style="color: var(--color-text); font-family: Georgia, serif"
              >
                James the Butler
              </p>
              <p class="text-xs" style="color: var(--color-text-dim)">
                v0.1.0 — AI-native agent platform
              </p>
            </div>
          </div>

          <p
            class="text-xs leading-relaxed"
            style="color: var(--color-text-dim)"
          >
            An open-source platform for orchestrating AI agents. Built with
            Elixir/Phoenix on the backend and Vue 3 on the frontend. Features a
            meta-planner, multi-session management, MCP server support, and a
            desktop app powered by Tauri.
          </p>

          <div class="flex flex-col gap-1.5">
            <a
              href="https://github.com/r3dlex/james-the-butler"
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center gap-2 text-xs transition-colors hover:text-[var(--color-gold)]"
              style="color: var(--color-accent-blue)"
            >
              <!-- GitHub icon -->
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="14"
                height="14"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path
                  d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"
                />
              </svg>
              GitHub Repository
            </a>

            <a
              href="https://github.com/r3dlex/james-the-butler/issues"
              target="_blank"
              rel="noopener noreferrer"
              class="flex items-center gap-2 text-xs transition-colors hover:text-[var(--color-gold)]"
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
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
              Report an Issue
            </a>
          </div>

          <p class="text-xs" style="color: var(--color-text-dim)">
            Licensed under MIT.
          </p>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive, onMounted } from "vue";
import { useLogoSrc } from "@/composables/useLogoSrc";
import { applyTheme } from "@/utils/theme";
import type { ThemeMode } from "@/utils/theme";

const logoSrc = useLogoSrc();
const STORAGE_KEY = "james_general_settings";

interface GeneralSettings {
  theme: ThemeMode;
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

function onThemeChange() {
  applyTheme(settings.theme);
  save();
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
