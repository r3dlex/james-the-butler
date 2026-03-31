<template>
  <div class="px-4 py-3">
    <div
      class="mb-1 text-xs font-semibold uppercase tracking-wide"
      :style="{ color: roleColor }"
    >
      {{ message.role === "user" ? "You" : "James" }}
    </div>
    <div
      v-for="(block, i) in message.content"
      :key="i"
      class="text-sm leading-relaxed"
      style="color: var(--color-text)"
    >
      <div
        v-if="block.type === 'text'"
        class="prose-invert whitespace-pre-wrap"
        v-html="renderMarkdown(block.text ?? '')"
      />
      <div
        v-else-if="block.type === 'thinking'"
        class="my-2 rounded-md border px-3 py-2 text-xs italic"
        style="border-color: var(--color-border); color: var(--color-text-dim)"
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
</template>

<script setup lang="ts">
import { computed } from "vue";
import MarkdownIt from "markdown-it";
import type { Message } from "@/types/message";

const props = defineProps<{ message: Message }>();

const md = new MarkdownIt({ html: false, linkify: true, breaks: true });

const roleColor = computed(() =>
  props.message.role === "user"
    ? "var(--color-gold)"
    : "var(--color-accent-blue)",
);

function renderMarkdown(text: string): string {
  return md.render(text);
}
</script>
