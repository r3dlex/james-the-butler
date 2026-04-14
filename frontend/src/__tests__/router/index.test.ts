// @vitest-environment happy-dom
import { it, expect, vi, beforeEach, afterEach } from "vitest";
import { createPinia, setActivePinia } from "pinia";

// ── localStorage stub ──────────────────────────────────────────────────────────
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

// ── Module mocks ─────────────────────────────────────────────────────────────
// The auth store mock is captured in a plain object so tests can mutate
// isAuthenticated and have that reflected in the router guard.
const mockAuthState = { isAuthenticated: false };
const mockTestConnection = vi.fn().mockResolvedValue(undefined);
const mockProviderStoreImpl = vi.fn(() => ({
  providers: [
    {
      id: "p1",
      status: "untested" as const,
      lastTestedAt: null as string | null,
      testConnection: mockTestConnection,
    },
  ],
}));

vi.mock("@/stores/auth", () => ({
  useAuthStore: vi.fn(() => mockAuthState),
}));

vi.mock("@/stores/providers", () => ({
  useProviderStore: mockProviderStoreImpl,
}));

// ── Router import — guards fire immediately at module load ───────────────────
import router from "@/router/index";

beforeEach(async () => {
  setActivePinia(createPinia());
  mockAuthState.isAuthenticated = false;
  localStorageMock.clear();
  vi.clearAllMocks();
  // Reset to a known non-settings path before each test
  await router.push("/login");
});

afterEach(async () => {
  localStorageMock.clear();
  // Drain any pending async work from afterEach dynamic imports
  await new Promise((r) => setTimeout(r, 50));
});

// ── beforeEach guard tests ─────────────────────────────────────────────────────
// Routes use dynamic imports so they have no .name property — verify via path.

it("beforeEach: public route passes without auth check", async () => {
  await router.push("/login");
  // Public route — guard returns true, navigation succeeds
  expect(router.currentRoute.value.path).toBe("/login");
});

it("beforeEach: authenticated user passes through", async () => {
  mockAuthState.isAuthenticated = true;
  await router.push("/sessions");
  expect(router.currentRoute.value.path).toBe("/sessions");
});

it("beforeEach: unauthenticated user redirects to /login", async () => {
  await router.push("/sessions");
  expect(router.currentRoute.value.path).toBe("/login");
});

// ── afterEach guard tests ─────────────────────────────────────────────────────
// afterEach fires a dynamic import that calls testConnection on the
// provider store. We verify the store was called and that the
// testConnection method exists on the returned object.

it("afterEach: navigating into /settings triggers provider health check", async () => {
  mockAuthState.isAuthenticated = true;
  await router.push("/login"); // start outside settings
  await router.isReady();

  mockProviderStoreImpl.mockReturnValueOnce({
    providers: [
      {
        id: "p1",
        status: "untested" as const,
        lastTestedAt: null as string | null,
        testConnection: mockTestConnection,
      },
    ],
  });

  await router.push("/settings/general");
  await router.isReady();
  // afterEach fires via lazy import — give it time to resolve
  await new Promise((r) => setTimeout(r, 80));

  expect(mockProviderStoreImpl).toHaveBeenCalled();
});

it("afterEach: navigating within /settings does NOT trigger provider health check", async () => {
  mockAuthState.isAuthenticated = true;

  // Pre-load the settings page so the dynamic import resolves now
  // and the afterEach promise from the previous test has settled.
  await router.push("/settings/general");
  await router.isReady();
  await new Promise((r) => setTimeout(r, 80));

  const callsBefore = mockProviderStoreImpl.mock.calls.length;

  await router.push("/settings/models");
  await router.isReady();
  // afterEach dynamic import must NOT fire again
  await new Promise((r) => setTimeout(r, 80));

  expect(mockProviderStoreImpl.mock.calls.length).toBe(callsBefore);
});
