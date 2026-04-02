<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition-opacity duration-150"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="open"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
        style="background: rgba(0, 0, 0, 0.6)"
        @click.self="$emit('cancel')"
      >
        <Transition
          enter-active-class="transition-all duration-150 ease-out"
          enter-from-class="opacity-0 scale-95"
          enter-to-class="opacity-100 scale-100"
        >
          <div
            v-if="open"
            class="w-full max-w-sm rounded-xl border p-6 shadow-2xl"
            style="
              background: var(--color-navy);
              border-color: var(--color-border);
            "
            role="dialog"
            :aria-label="title"
          >
            <!-- Icon + title -->
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
                <h2
                  class="text-base font-semibold"
                  style="color: var(--color-text)"
                >
                  {{ title }}
                </h2>
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

            <!-- Actions -->
            <div class="mt-6 flex justify-end gap-2">
              <button
                type="button"
                class="rounded-lg px-4 py-2 text-sm font-medium transition-colors hover:bg-[var(--color-surface)]"
                style="
                  border: 1px solid var(--color-border);
                  color: var(--color-text-dim);
                "
                @click="$emit('cancel')"
              >
                {{ cancelLabel }}
              </button>
              <button
                type="button"
                class="rounded-lg px-4 py-2 text-sm font-medium transition-opacity hover:opacity-90"
                :style="confirmStyle"
                @click="$emit('confirm')"
              >
                {{ confirmLabel }}
              </button>
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { computed } from "vue";

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

defineEmits<{
  confirm: [];
  cancel: [];
}>();

const confirmStyle = computed(() =>
  props.variant === "danger"
    ? "background: var(--color-risk-red); color: #fff;"
    : "background: var(--color-gold); color: var(--color-navy-deep);",
);
</script>
