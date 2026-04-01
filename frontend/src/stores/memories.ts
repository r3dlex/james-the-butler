import { defineStore } from "pinia";
import { ref } from "vue";
import { api } from "@/services/api";
import type { MemoryEntry } from "@/types/memory";

export const useMemoryStore = defineStore("memories", () => {
  const memories = ref<MemoryEntry[]>([]);
  const loading = ref(false);

  async function fetchMemories() {
    loading.value = true;
    try {
      const data = await api.get<{ memories: MemoryEntry[] }>("/api/memories");
      memories.value = data.memories;
    } catch {
      // fall through — memories stay empty when backend is unavailable
    } finally {
      loading.value = false;
    }
  }

  async function searchMemories(query: string) {
    loading.value = true;
    try {
      const encoded = encodeURIComponent(query);
      const data = await api.get<{ memories: MemoryEntry[] }>(
        `/api/memories?q=${encoded}`,
      );
      memories.value = data.memories;
    } catch {
      // fall through
    } finally {
      loading.value = false;
    }
  }

  async function deleteMemory(id: string) {
    try {
      await api.delete(`/api/memories/${id}`);
    } catch {
      // ok in dev mode
    }
    memories.value = memories.value.filter((m) => m.id !== id);
  }

  async function updateMemory(id: string, data: Partial<MemoryEntry>) {
    try {
      const response = await api.put<{ memory: MemoryEntry }>(
        `/api/memories/${id}`,
        data,
      );
      const idx = memories.value.findIndex((m) => m.id === id);
      if (idx !== -1) memories.value[idx] = response.memory;
      return response.memory;
    } catch {
      return null;
    }
  }

  return {
    memories,
    loading,
    fetchMemories,
    searchMemories,
    deleteMemory,
    updateMemory,
  };
});
