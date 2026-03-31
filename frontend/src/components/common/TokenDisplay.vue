<template>
  <div
    class="flex items-center gap-2 text-xs tabular-nums"
    style="color: var(--color-text-dim)"
  >
    <span>{{ formattedTokens }} tokens</span>
    <span class="opacity-50">|</span>
    <span style="color: var(--color-gold)">${{ formattedCost }}</span>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";

const props = defineProps<{ tokens: number; cost: number }>();

const formattedTokens = computed(() => props.tokens.toLocaleString());
const formattedCost = computed(() => props.cost.toFixed(4));
</script>
