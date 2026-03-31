import { defineStore } from "pinia";
import { ref } from "vue";
import { api } from "@/services/api";
import type { Host } from "@/types/host";

export const useHostStore = defineStore("hosts", () => {
  const hosts = ref<Host[]>([]);
  const loading = ref(false);

  async function fetchHosts() {
    loading.value = true;
    try {
      const data = await api.get<{ data: Host[] }>("/api/hosts");
      hosts.value = data.data;
    } catch {
      // TODO: error handling
    } finally {
      loading.value = false;
    }
  }

  function getHost(id: string): Host | undefined {
    return hosts.value.find((h) => h.id === id);
  }

  function updateHost(updated: Host) {
    const idx = hosts.value.findIndex((h) => h.id === updated.id);
    if (idx !== -1) hosts.value[idx] = updated;
  }

  return { hosts, loading, fetchHosts, getHost, updateHost };
});
