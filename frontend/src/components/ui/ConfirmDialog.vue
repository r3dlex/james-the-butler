<template>
  <Dialog
    v-model:visible="visible"
    :header="title"
    :modal="true"
    :closable="true"
    :style="{
      background: 'var(--color-navy)',
      border: '1px solid var(--color-border)',
      borderRadius: '0.75rem',
    }"
    :pt="{
      root: { class: 'border' },
      header: { class: 'p-4' },
      content: { class: 'p-4' },
      footer: { class: 'p-4 pt-0 flex justify-end gap-2' },
    }"
    @hide="$emit('cancel')"
  >
    <div class="mb-4 flex items-start gap-3">
      <div
        v-if="variant === 'danger'"
        class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full"
        style="background: rgba(239, 68, 68, 0.15)"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          style="color: var(--color-risk-red)"
        >
          <path
            d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"
          />
          <line x1="12" y1="9" x2="12" y2="13" />
          <line x1="12" y1="17" x2="12.01" y2="17" />
        </svg>
      </div>
      <div>
        <p
          v-if="description"
          class="mt-1 text-sm leading-relaxed"
          style="color: var(--color-text-dim)"
        >
          {{ description }}
        </p>
      </div>
    </div>

    <!-- Extra slot for custom content -->
    <slot />

    <template #footer>
      <button
        type="button"
        class="rounded-lg px-4 py-2 text-sm font-medium transition-colors hover:bg-[var(--color-surface)]"
        style="
          border: 1px solid var(--color-border);
          color: var(--color-text-dim);
        "
        @click="onCancel"
      >
        {{ cancelLabel }}
      </button>
      <button
        type="button"
        class="rounded-lg px-4 py-2 text-sm font-medium transition-opacity hover:opacity-90"
        :style="confirmStyle"
        @click="onConfirm"
      >
        {{ confirmLabel }}
      </button>
    </template>
  </Dialog>
</template>

<script setup lang="ts">
import { computed } from "vue";
import Dialog from "primevue/dialog";

const props = withDefaults(
  defineProps<{
    open: boolean;
    title: string;
    description?: string;
    confirmLabel?: string;
    cancelLabel?: string;
    variant?: "default" | "danger";
  }>(),
  {
    confirmLabel: "Confirm",
    cancelLabel: "Cancel",
    variant: "default",
  },
);

const emit = defineEmits<{
  confirm: [];
  cancel: [];
  hide: [];
}>();

const visible = computed({
  get: () => props.open,
  set: (val) => {
    if (!val) emit("cancel");
  },
});

const confirmStyle = computed(() =>
  props.variant === "danger"
    ? "background: var(--color-risk-red); color: #fff;"
    : "background: var(--color-gold); color: var(--color-navy-deep);",
);

function onConfirm() {
  emit("confirm");
}

function onCancel() {
  emit("cancel");
}
</script>
