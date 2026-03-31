<template>
  <div ref="containerRef" class="flex-1 overflow-y-auto">
    <EmptyState
      v-if="messages.length === 0 && !isStreaming"
      message="Start a conversation"
    >
      <template #icon>
        <img src="/logo.svg" alt="" width="48" height="48" class="opacity-40" />
      </template>
    </EmptyState>

    <MessageBubble v-for="msg in messages" :key="msg.id" :message="msg" />

    <!-- Streaming indicator -->
    <div v-if="isStreaming" class="px-4 py-3">
      <div
        class="mb-1 text-xs font-semibold uppercase tracking-wide"
        style="color: var(--color-accent-blue)"
      >
        James
      </div>
      <div class="flex gap-1 py-2">
        <span
          v-for="n in 3"
          :key="n"
          class="h-2 w-2 animate-pulse rounded-full"
          style="background: var(--color-gold)"
          :style="{ animationDelay: `${(n - 1) * 200}ms` }"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, nextTick } from "vue";
import type { Message } from "@/types/message";
import MessageBubble from "./MessageBubble.vue";
import EmptyState from "@/components/common/EmptyState.vue";

const props = defineProps<{
  messages: Message[];
  isStreaming: boolean;
}>();

const containerRef = ref<HTMLElement | null>(null);

watch(
  () => props.messages.length,
  () => {
    nextTick(() => {
      if (containerRef.value) {
        containerRef.value.scrollTop = containerRef.value.scrollHeight;
      }
    });
  },
);
</script>
