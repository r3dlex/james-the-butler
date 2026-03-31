<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">Desktop Control</h1>
    <div class="max-w-lg space-y-4">
      <div class="rounded-md border p-4" style="border-color: var(--color-border)">
        <p class="text-sm" style="color: var(--color-text)">Desktop Control Daemon</p>
        <p class="mt-1 text-xs" style="color: var(--color-text-dim)">
          Configure the desktop control daemon for screen capture and input automation.
          Requires Accessibility and Screen Recording permissions on macOS.
        </p>
        <div class="mt-3 flex items-center gap-2">
          <span class="inline-block h-2 w-2 rounded-full" style="background: var(--color-text-dim)" />
          <span class="text-xs" style="color: var(--color-text-dim)">Daemon not running</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>
