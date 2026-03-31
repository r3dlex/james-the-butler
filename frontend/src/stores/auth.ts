import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { api } from "@/services/api";
import { connectSocket, disconnectSocket } from "@/services/phoenix";

export interface User {
  id: string;
  email: string;
  name: string;
  avatarUrl: string | null;
}

export const useAuthStore = defineStore("auth", () => {
  const user = ref<User | null>(null);
  const token = ref<string | null>(localStorage.getItem("auth_token"));
  const loading = ref(false);
  const error = ref<string | null>(null);

  const isAuthenticated = computed(() => !!token.value);

  function setAuth(newToken: string, newUser: User) {
    token.value = newToken;
    user.value = newUser;
    localStorage.setItem("auth_token", newToken);
    api.setToken(newToken);
    connectSocket();
  }

  function logout() {
    token.value = null;
    user.value = null;
    localStorage.removeItem("auth_token");
    api.setToken(null);
    disconnectSocket();
  }

  async function fetchCurrentUser() {
    if (!token.value) return;
    loading.value = true;
    try {
      api.setToken(token.value);
      const data = await api.get<{ data: User }>("/api/me");
      user.value = data.data;
      connectSocket();
    } catch {
      logout();
    } finally {
      loading.value = false;
    }
  }

  async function loginWithProvider(provider: string) {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.get<{ url: string }>(`/api/auth/${provider}`);
      window.location.href = data.url;
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : "Login failed";
    } finally {
      loading.value = false;
    }
  }

  // Dev mode: skip OAuth, auto-authenticate
  function devLogin() {
    const devUser: User = {
      id: "dev-user",
      email: "dev@james.local",
      name: "Developer",
      avatarUrl: null,
    };
    setAuth("dev-token", devUser);
  }

  return {
    user,
    token,
    loading,
    error,
    isAuthenticated,
    setAuth,
    logout,
    fetchCurrentUser,
    loginWithProvider,
    devLogin,
  };
});
