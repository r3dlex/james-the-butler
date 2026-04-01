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

const mockGet = vi.fn();
const mockPost = vi.fn();
const mockDelete = vi.fn();

vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: mockGet,
    post: mockPost,
    delete: mockDelete,
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(),
}));

const makePreset = (id: string, name: string) => ({
  id,
  name,
  prompt: `You are ${name}.`,
});

const makeProfile = (id: string, name: string, userId = "user-1") => ({
  id,
  name,
  preset: "butler",
  customPrompt: null,
  userId,
  insertedAt: new Date().toISOString(),
});

describe("usePersonalityStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("is importable and usable", async () => {
    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    expect(store).toBeDefined();
  });

  it("presets starts as empty array", async () => {
    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    expect(store.presets).toEqual([]);
  });

  it("profiles starts as empty array", async () => {
    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    expect(store.profiles).toEqual([]);
  });

  it("loading starts as false", async () => {
    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    expect(store.loading).toBe(false);
  });

  // ---------------------------------------------------------------------------
  // fetchPresets
  // ---------------------------------------------------------------------------

  it("fetchPresets loads presets from the API", async () => {
    const presetList = [
      makePreset("butler", "Butler"),
      makePreset("collaborator", "Collaborator"),
      makePreset("analyst", "Analyst"),
      makePreset("coach", "Coach"),
      makePreset("editor", "Editor"),
      makePreset("silent", "Silent"),
    ];
    mockGet.mockResolvedValueOnce({ presets: presetList });

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    await store.fetchPresets();

    expect(mockGet).toHaveBeenCalledWith("/api/personality/presets");
    expect(store.presets).toHaveLength(6);
    expect(store.presets[0].id).toBe("butler");
  });

  it("fetchPresets sets loading to false after completion", async () => {
    mockGet.mockResolvedValueOnce({ presets: [] });

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    await store.fetchPresets();

    expect(store.loading).toBe(false);
  });

  it("fetchPresets handles API error gracefully", async () => {
    mockGet.mockRejectedValueOnce(new Error("Network error"));

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    await expect(store.fetchPresets()).resolves.not.toThrow();
    expect(store.loading).toBe(false);
  });

  // ---------------------------------------------------------------------------
  // fetchProfiles
  // ---------------------------------------------------------------------------

  it("fetchProfiles loads custom profiles from the API", async () => {
    const profileList = [
      makeProfile("p-1", "Work Profile"),
      makeProfile("p-2", "Personal Profile"),
    ];
    mockGet.mockResolvedValueOnce({ profiles: profileList });

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    await store.fetchProfiles();

    expect(mockGet).toHaveBeenCalledWith("/api/personality/profiles");
    expect(store.profiles).toHaveLength(2);
    expect(store.profiles[0].name).toBe("Work Profile");
  });

  it("fetchProfiles sets loading to false after completion", async () => {
    mockGet.mockResolvedValueOnce({ profiles: [] });

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    await store.fetchProfiles();

    expect(store.loading).toBe(false);
  });

  it("fetchProfiles handles API error gracefully", async () => {
    mockGet.mockRejectedValueOnce(new Error("Network error"));

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    await expect(store.fetchProfiles()).resolves.not.toThrow();
    expect(store.loading).toBe(false);
  });

  // ---------------------------------------------------------------------------
  // createProfile
  // ---------------------------------------------------------------------------

  it("createProfile adds a new custom profile and returns it", async () => {
    const newProfile = makeProfile("p-new", "Custom Profile");
    mockPost.mockResolvedValueOnce({ profile: newProfile });

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    const result = await store.createProfile({
      name: "Custom Profile",
      preset: "butler",
    });

    expect(mockPost).toHaveBeenCalledWith("/api/personality/profiles", {
      name: "Custom Profile",
      preset: "butler",
    });
    expect(result).not.toBeNull();
    expect(result!.name).toBe("Custom Profile");
    expect(store.profiles).toHaveLength(1);
    expect(store.profiles[0].id).toBe("p-new");
  });

  it("createProfile appends to existing profiles", async () => {
    const existingProfile = makeProfile("p-1", "Existing Profile");
    const newProfile = makeProfile("p-2", "New Profile");

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    store.profiles.push(existingProfile);

    mockPost.mockResolvedValueOnce({ profile: newProfile });
    await store.createProfile({ name: "New Profile" });

    expect(store.profiles).toHaveLength(2);
  });

  it("createProfile returns null on API error", async () => {
    mockPost.mockRejectedValueOnce(new Error("Validation error"));

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    const result = await store.createProfile({ name: "" });

    expect(result).toBeNull();
    expect(store.profiles).toHaveLength(0);
  });

  // ---------------------------------------------------------------------------
  // deleteProfile
  // ---------------------------------------------------------------------------

  it("deleteProfile removes the profile from the store", async () => {
    const profile = makeProfile("p-del", "To Delete");
    mockDelete.mockResolvedValueOnce(undefined);

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    store.profiles.push(profile);

    const result = await store.deleteProfile("p-del");

    expect(mockDelete).toHaveBeenCalledWith("/api/personality/profiles/p-del");
    expect(result).toBe(true);
    expect(store.profiles).toHaveLength(0);
  });

  it("deleteProfile only removes the targeted profile", async () => {
    const p1 = makeProfile("p-keep", "Keep Me");
    const p2 = makeProfile("p-del", "Delete Me");
    mockDelete.mockResolvedValueOnce(undefined);

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    store.profiles.push(p1, p2);

    await store.deleteProfile("p-del");

    expect(store.profiles).toHaveLength(1);
    expect(store.profiles[0].id).toBe("p-keep");
  });

  it("deleteProfile returns false on API error", async () => {
    const profile = makeProfile("p-err", "Error Profile");
    mockDelete.mockRejectedValueOnce(new Error("Not found"));

    const { usePersonalityStore } = await import("../stores/personality");
    const store = usePersonalityStore();
    store.profiles.push(profile);

    const result = await store.deleteProfile("p-err");

    expect(result).toBe(false);
    expect(store.profiles).toHaveLength(1);
  });
});
