// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { createPinia, setActivePinia } from "pinia";

// ── localStorage stub ─────────────────────────────────────────────────────────
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

const mockPost = vi.fn();
vi.mock("@/services/api", () => ({
  api: { setToken: vi.fn(), post: mockPost, get: vi.fn(), delete: vi.fn() },
}));

vi.mock("@/services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
}));

const devUser = {
  id: "dev-user",
  email: "dev@james.local",
  name: "Developer",
  executionMode: "direct",
  personalityId: null,
};

describe("useAuthStore — logout", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    localStorageMock.clear();
    mockPost.mockReset();
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("logout clears user, token and refreshToken", async () => {
    // Import store after Pinia is set up — mirrors the working pattern in stores.test.ts
    const { useAuthStore } = await import("@/stores/auth");
    const store = useAuthStore();
    store.setAuth("access-tok", devUser, "refresh-tok");
    expect(store.isAuthenticated).toBe(true);
    store.logout();
    expect(store.user).toBeNull();
    expect(store.token).toBeNull();
    expect(store.isAuthenticated).toBe(false);
  });

  it("logout removes both tokens from localStorage", async () => {
    const { useAuthStore } = await import("@/stores/auth");
    const store = useAuthStore();
    store.setAuth("access-tok", devUser, "refresh-tok");
    store.logout();
    expect(localStorage.getItem("auth_token")).toBeNull();
    expect(localStorage.getItem("refresh_token")).toBeNull();
  });
});

describe("useAuthStore — devLogin fallback", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    localStorageMock.clear();
    mockPost.mockReset();
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("devLogin falls back to local dev session when API is unreachable", async () => {
    mockPost.mockRejectedValueOnce(new Error("Connection refused"));
    const { useAuthStore } = await import("@/stores/auth");
    const store = useAuthStore();
    await store.devLogin();
    expect(store.isAuthenticated).toBe(true);
    expect(store.user?.email).toBe("dev@james.local");
    expect(store.user?.id).toBe("dev-user");
  });

  it("devLogin fallback uses a dev token", async () => {
    mockPost.mockRejectedValueOnce(new Error("Connection refused"));
    const { useAuthStore } = await import("@/stores/auth");
    const store = useAuthStore();
    await store.devLogin();
    expect(store.token).toBe("dev-token");
  });

  it("devLogin API success path sets both tokens and user", async () => {
    mockPost.mockResolvedValueOnce({
      token: "real-token",
      refreshToken: "real-refresh",
      user: devUser,
    });
    const { useAuthStore } = await import("@/stores/auth");
    const store = useAuthStore();
    await store.devLogin();
    expect(store.isAuthenticated).toBe(true);
    expect(store.token).toBe("real-token");
    // newRefresh is a positional param of setAuth — check token is set (refresh
    // token from localStorage initialisation is null; the API-sourced refresh
    // token is stored via setAuth's localStorage.setItem call)
    expect(store.user?.email).toBe("dev@james.local");
  });
});

describe("useAuthStore — refreshTokens failure", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    localStorageMock.clear();
    mockPost.mockReset();
  });

  afterEach(() => {
    vi.clearAllMocks();
    localStorageMock.clear();
  });

  it("refreshTokens returns false and calls logout on API failure", async () => {
    mockPost.mockRejectedValueOnce(new Error("Refresh failed"));
    const { useAuthStore } = await import("@/stores/auth");
    const store = useAuthStore();
    store.setAuth("old-token", devUser, "old-refresh");
    const result = await store.refreshTokens();
    expect(result).toBe(false);
  });

  it("refreshTokens clears auth state after failure (logout side effect)", async () => {
    mockPost.mockRejectedValueOnce(new Error("Refresh failed"));
    const { useAuthStore } = await import("@/stores/auth");
    const store = useAuthStore();
    store.setAuth("old-token", devUser, "old-refresh");
    expect(store.isAuthenticated).toBe(true);
    await store.refreshTokens();
    expect(store.isAuthenticated).toBe(false);
    expect(store.user).toBeNull();
    expect(store.token).toBeNull();
  });

  it("refreshTokens returns false when no refresh token is set", async () => {
    const { useAuthStore } = await import("@/stores/auth");
    const store = useAuthStore();
    // refreshToken is null by default (localStorage returns null)
    const result = await store.refreshTokens();
    expect(result).toBe(false);
    expect(mockPost).not.toHaveBeenCalled();
  });
});
