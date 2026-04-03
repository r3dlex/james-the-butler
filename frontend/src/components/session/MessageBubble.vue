<template>
  <div :class="wrapperClass">
    <div :class="bubbleClass">
      <div
        v-for="(block, i) in message.content"
        :key="i"
        class="text-sm leading-relaxed"
      >
        <div
          v-if="block.type === 'text'"
          class="prose-invert whitespace-pre-wrap"
          :style="{ color: textColor }"
          v-html="renderMarkdown(block.text ?? '')"
        />
        <div
          v-else-if="block.type === 'thinking'"
          class="my-2 rounded-md border px-3 py-2 text-xs italic"
          style="
            border-color: var(--color-border);
            color: var(--color-text-dim);
          "
        >
          {{ block.text }}
        </div>
        <div
          v-else-if="block.type === 'command_log'"
          class="my-2 rounded-md p-3 font-mono text-xs"
          style="background: var(--color-surface)"
        >
          <div style="color: var(--color-gold)">$ {{ block.command }}</div>
          <pre
            v-if="block.output"
            class="mt-1 whitespace-pre-wrap"
            style="color: var(--color-text-dim)"
            >{{ block.output }}</pre
          >
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import MarkdownIt from "markdown-it";
import type { Message } from "@/types/message";

const props = defineProps<{ message: Message }>();

const md = new MarkdownIt({ html: false, linkify: true, breaks: true });

const isUser = computed(() => props.message.role === "user");

const wrapperClass = computed(() =>
  isUser.value ? "px-4 py-2 flex justify-end" : "px-4 py-2",
);

const bubbleClass = computed(() =>
  isUser.value
    ? "max-w-[80%] rounded-xl px-4 py-2 bg-neutral-900 text-white"
    : "max-w-full",
);

const textColor = computed(() =>
  isUser.value ? "#ffffff" : "var(--color-text)",
);

function renderMarkdown(text: string): string {
  return md.render(text);
}
</script>
