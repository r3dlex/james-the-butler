<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">Security</h1>
    <div class="max-w-lg space-y-4">
      <div class="rounded-md border p-4" style="border-color: var(--color-border)">
        <h3 class="text-sm font-medium" style="color: var(--color-text)">Multi-Factor Authentication</h3>
        <p class="mt-1 text-xs" style="color: var(--color-text-dim)">MFA setup will be available in a future update.</p>
        <button
          class="mt-2 rounded px-3 py-1.5 text-sm font-medium opacity-50"
          style="background: var(--color-gold); color: var(--color-navy-deep)"
          disabled
        >
          Set Up MFA
        </button>
      </div>
      <div class="rounded-md border p-4" style="border-color: var(--color-border)">
        <h3 class="text-sm font-medium" style="color: var(--color-text)">OAuth Providers</h3>
        <p class="mt-1 text-xs" style="color: var(--color-text-dim)">Manage connected OAuth providers (Google, Microsoft, GitHub).</p>
        <div class="mt-2 space-y-1">
          <div v-for="provider in ['Google', 'Microsoft', 'GitHub']" :key="provider" class="flex items-center justify-between py-1">
            <span class="text-sm" style="color: var(--color-text)">{{ provider }}</span>
            <span class="text-xs" style="color: var(--color-text-dim)">Not connected</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>
