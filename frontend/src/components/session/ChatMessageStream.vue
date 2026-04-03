<template>
  <div ref="containerRef" class="flex-1 overflow-y-auto">
    <EmptyState
      v-if="messages.length === 0 && !isStreaming"
      message="Start a conversation"
    >
      <template #icon>
        <img :src="logoSrc" alt="" width="48" height="48" class="opacity-40" />
      </template>
    </EmptyState>

    <MessageBubble v-for="msg in messages" :key="msg.id" :message="msg" />

    <!-- Streaming assistant response -->
    <div v-if="isStreaming" class="px-4 py-2">
      <div
        v-if="streamingText"
        class="text-sm leading-relaxed"
        style="color: var(--color-text)"
      >
        <div
          class="prose-invert whitespace-pre-wrap"
          v-html="renderMarkdown(streamingText)"
        />
      </div>
      <div v-else class="flex gap-1 py-2">
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
import { useLogoSrc } from "@/composables/useLogoSrc";
import MarkdownIt from "markdown-it";
import type { Message } from "@/types/message";
import MessageBubble from "./MessageBubble.vue";
import EmptyState from "@/components/common/EmptyState.vue";

const logoSrc = useLogoSrc();
const md = new MarkdownIt({ html: false, linkify: true, breaks: true });

function renderMarkdown(text: string): string {
  return md.render(text);
}

const props = defineProps<{
  messages: Message[];
  isStreaming: boolean;
  streamingText?: string;
}>();

const containerRef = ref<HTMLElement | null>(null);

function scrollToBottom() {
  nextTick(() => {
    if (containerRef.value) {
      containerRef.value.scrollTop = containerRef.value.scrollHeight;
    }
  });
}

watch(() => props.messages.length, scrollToBottom);
watch(() => props.streamingText, scrollToBottom);
</script>
