// @vitest-environment happy-dom
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { createPinia, setActivePinia } from "pinia";

const localStorageData: Record<string, string> = {};
const localStorageMock = {
  getItem: (key: string) => localStorageData[key] ?? null,
  setItem: (key: string, val: string) => {
    localStorageData[key] = val;
  },
  removeItem: (key: string) => {
    delete localStorageData[key];
  },
  clear: () => {
    for (const k of Object.keys(localStorageData)) delete localStorageData[k];
  },
  get length() {
    return Object.keys(localStorageData).length;
  },
  key: (i: number) => Object.keys(localStorageData)[i] ?? null,
};
vi.stubGlobal("localStorage", localStorageMock);

vi.mock("../services/api", () => ({
  api: { setToken: vi.fn(), get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

describe("useTokenStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("is importable and usable", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    expect(store).toBeDefined();
  });

  it("totalCost starts at 0", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    expect(store.totalCost).toBe(0);
  });

  it("isOverBudget is false when no budget set", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    expect(store.isOverBudget).toBe(false);
  });

  it("isBudgetWarning is false when no budget set", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    expect(store.isBudgetWarning).toBe(false);
  });

  it("getUsage returns null for unknown session", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    expect(store.getUsage("unknown")).toBeNull();
  });

  it("updateUsage creates new entry for a session", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    store.updateUsage("sess-1", {
      inputTokens: 100,
      outputTokens: 50,
      cost: 0.01,
    });
    const usage = store.getUsage("sess-1");
    expect(usage).not.toBeNull();
    expect(usage!.inputTokens).toBe(100);
    expect(usage!.outputTokens).toBe(50);
    expect(usage!.cost).toBe(0.01);
  });

  it("updateUsage merges with existing data", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    store.updateUsage("sess-2", { inputTokens: 100, cost: 0.01 });
    store.updateUsage("sess-2", { outputTokens: 200 });
    const usage = store.getUsage("sess-2");
    expect(usage!.inputTokens).toBe(100);
    expect(usage!.outputTokens).toBe(200);
    expect(usage!.cost).toBe(0.01);
  });

  it("totalCost sums costs across all sessions", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    store.updateUsage("s1", { cost: 0.05 });
    store.updateUsage("s2", { cost: 0.1 });
    expect(store.totalCost).toBeCloseTo(0.15);
  });

  it("isOverBudget is true when cost exceeds budget", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    store.globalBudget = 0.05;
    store.updateUsage("s1", { cost: 0.1 });
    expect(store.isOverBudget).toBe(true);
  });

  it("isOverBudget is false when cost is under budget", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    store.globalBudget = 1.0;
    store.updateUsage("s1", { cost: 0.1 });
    expect(store.isOverBudget).toBe(false);
  });

  it("isBudgetWarning is true when cost exceeds threshold", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    store.globalBudget = 1.0;
    store.budgetAlertThreshold = 0.8;
    store.updateUsage("s1", { cost: 0.85 });
    expect(store.isBudgetWarning).toBe(true);
  });

  it("isBudgetWarning is false when cost is under threshold", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    store.globalBudget = 1.0;
    store.budgetAlertThreshold = 0.8;
    store.updateUsage("s1", { cost: 0.5 });
    expect(store.isBudgetWarning).toBe(false);
  });

  it("budgetAlertThreshold defaults to 0.8", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    expect(store.budgetAlertThreshold).toBe(0.8);
  });

  it("globalBudget defaults to null", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    expect(store.globalBudget).toBeNull();
  });

  it("updateUsage defaults missing fields to 0", async () => {
    const { useTokenStore } = await import("../stores/tokens");
    const store = useTokenStore();
    store.updateUsage("sess-zero", {});
    const usage = store.getUsage("sess-zero");
    expect(usage!.inputTokens).toBe(0);
    expect(usage!.outputTokens).toBe(0);
    expect(usage!.cost).toBe(0);
  });
});
