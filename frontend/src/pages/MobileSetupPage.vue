<template>
  <div class="p-6">
    <h1 class="mb-4 text-lg font-medium" style="color: var(--color-text)">
      Mobile Setup
    </h1>

    <div class="max-w-md space-y-4">
      <div
        class="rounded-md border p-6 text-center"
        style="border-color: var(--color-border)"
      >
        <div
          class="mx-auto mb-4 flex h-48 w-48 items-center justify-center rounded-lg border-2 border-dashed"
          style="border-color: var(--color-border)"
        >
          <div class="text-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="48"
              height="48"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              style="color: var(--color-text-dim)"
              class="mx-auto"
            >
              <rect width="5" height="5" x="3" y="3" rx="1" />
              <rect width="5" height="5" x="16" y="3" rx="1" />
              <rect width="5" height="5" x="3" y="16" rx="1" />
              <path d="M21 16h-3a2 2 0 0 0-2 2v3" />
              <path d="M21 21v.01" />
              <path d="M12 7v3a2 2 0 0 1-2 2H7" />
              <path d="M3 12h.01" />
              <path d="M12 3h.01" />
              <path d="M12 16v.01" />
              <path d="M16 12h1" />
              <path d="M21 12v.01" />
              <path d="M12 21v-1" />
            </svg>
            <p class="mt-2 text-xs" style="color: var(--color-text-dim)">
              QR Code
            </p>
          </div>
        </div>
        <p class="text-sm" style="color: var(--color-text)">
          Scan with the James mobile app
        </p>
        <p class="mt-1 text-xs" style="color: var(--color-text-dim)">
          The QR code contains your host binding token for secure pairing.
        </p>
        <button
          class="mt-4 rounded px-4 py-1.5 text-sm font-medium"
          style="background: var(--color-gold); color: var(--color-navy-deep)"
          @click="generateCode"
        >
          Generate QR Code
        </button>
      </div>

      <div
        class="rounded-md border p-4"
        style="border-color: var(--color-border)"
      >
        <h3 class="text-sm font-medium" style="color: var(--color-text)">
          Manual Setup
        </h3>
        <p class="mt-1 text-xs" style="color: var(--color-text-dim)">
          Enter the host endpoint URL in the mobile app settings instead of
          scanning.
        </p>
        <div
          class="mt-2 rounded border px-3 py-1.5 text-xs font-mono"
          style="
            border-color: var(--color-border);
            color: var(--color-text-dim);
          "
        >
          {{ hostEndpoint }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";

const hostEndpoint = ref(window.location.origin);

function generateCode() {
  // QR code generation will be implemented with the mobile app
}
</script>
