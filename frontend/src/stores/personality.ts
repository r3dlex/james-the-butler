import { defineStore } from "pinia";
import { ref } from "vue";
import { api } from "@/services/api";

export interface PersonalityPreset {
  id: string;
  name: string;
  prompt: string;
}

export interface PersonalityProfile {
  id: string;
  name: string;
  preset: string | null;
  customPrompt: string | null;
  userId: string;
  insertedAt: string;
}

export const usePersonalityStore = defineStore("personality", () => {
  const presets = ref<PersonalityPreset[]>([]);
  const profiles = ref<PersonalityProfile[]>([]);
  const loading = ref(false);

  async function fetchPresets() {
    loading.value = true;
    try {
      const data = await api.get<{ presets: PersonalityPreset[] }>(
        "/api/personality/presets",
      );
      presets.value = data.presets;
    } catch {
      // TODO: error handling
    } finally {
      loading.value = false;
    }
  }

  async function fetchProfiles() {
    loading.value = true;
    try {
      const data = await api.get<{ profiles: PersonalityProfile[] }>(
        "/api/personality/profiles",
      );
      profiles.value = data.profiles;
    } catch {
      // TODO: error handling
    } finally {
      loading.value = false;
    }
  }

  async function createProfile(data: {
    name: string;
    preset?: string;
    customPrompt?: string;
  }): Promise<PersonalityProfile | null> {
    try {
      const result = await api.post<{ profile: PersonalityProfile }>(
        "/api/personality/profiles",
        data,
      );
      profiles.value.push(result.profile);
      return result.profile;
    } catch {
      // TODO: error handling
      return null;
    }
  }

  async function deleteProfile(id: string): Promise<boolean> {
    try {
      await api.delete(`/api/personality/profiles/${id}`);
      profiles.value = profiles.value.filter((p) => p.id !== id);
      return true;
    } catch {
      // TODO: error handling
      return false;
    }
  }

  return {
    presets,
    profiles,
    loading,
    fetchPresets,
    fetchProfiles,
    createProfile,
    deleteProfile,
  };
});
