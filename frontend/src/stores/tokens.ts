import { defineStore } from "pinia";
import { ref, computed } from "vue";

export interface TokenUsage {
  sessionId: string;
  inputTokens: number;
  outputTokens: number;
  cost: number;
}

export const useTokenStore = defineStore("tokens", () => {
  const usageBySession = ref<Map<string, TokenUsage>>(new Map());
  const globalBudget = ref<number | null>(null);
  const budgetAlertThreshold = ref(0.8);

  const totalCost = computed(() => {
    let sum = 0;
    usageBySession.value.forEach((u) => (sum += u.cost));
    return sum;
  });

  const isOverBudget = computed(() => {
    if (!globalBudget.value) return false;
    return totalCost.value >= globalBudget.value;
  });

  const isBudgetWarning = computed(() => {
    if (!globalBudget.value) return false;
    return totalCost.value >= globalBudget.value * budgetAlertThreshold.value;
  });

  function updateUsage(sessionId: string, usage: Partial<TokenUsage>) {
    const existing = usageBySession.value.get(sessionId) ?? {
      sessionId,
      inputTokens: 0,
      outputTokens: 0,
      cost: 0,
    };
    usageBySession.value.set(sessionId, { ...existing, ...usage });
  }

  function getUsage(sessionId: string): TokenUsage | null {
    return usageBySession.value.get(sessionId) ?? null;
  }

  return {
    usageBySession,
    globalBudget,
    budgetAlertThreshold,
    totalCost,
    isOverBudget,
    isBudgetWarning,
    updateUsage,
    getUsage,
  };
});
