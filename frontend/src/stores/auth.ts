import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { api } from "@/services/api";
import { connectSocket, disconnectSocket } from "@/services/phoenix";

export interface User {
  id: string;
  email: string;
  name: string;
  executionMode: string;
  personalityId: string | null;
}

export const useAuthStore = defineStore("auth", () => {
  const user = ref<User | null>(null);
  const token = ref<string | null>(localStorage.getItem("auth_token"));
  const refreshToken = ref<string | null>(
    localStorage.getItem("refresh_token"),
  );
  const loading = ref(false);
  const error = ref<string | null>(null);

  const isAuthenticated = computed(() => !!token.value);

  function setAuth(newToken: string, newUser: User, newRefresh?: string) {
    token.value = newToken;
    user.value = newUser;
    localStorage.setItem("auth_token", newToken);
    if (newRefresh) {
      refreshToken.value = newRefresh;
      localStorage.setItem("refresh_token", newRefresh);
    }
    api.setToken(newToken);
    connectSocket();
  }

  function logout() {
    token.value = null;
    user.value = null;
    refreshToken.value = null;
    localStorage.removeItem("auth_token");
    localStorage.removeItem("refresh_token");
    api.setToken(null);
    disconnectSocket();
  }

  async function fetchCurrentUser() {
    if (!token.value) return;
    loading.value = true;
    try {
      api.setToken(token.value);
      const data = await api.get<{ user: User }>("/api/auth/me");
      user.value = data.user;
      connectSocket();
    } catch {
      logout();
    } finally {
      loading.value = false;
    }
  }

  function loginWithProvider(provider: string) {
    window.location.href = `http://localhost:4000/api/auth/${provider}`;
  }

  // Calls the real backend dev login endpoint
  async function devLogin() {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.post<{
        token: string;
        refreshToken: string;
        user: User;
      }>("/api/auth/dev_login", {
        email: "dev@james.local",
        name: "Developer",
      });
      setAuth(data.token, data.user, data.refreshToken);
    } catch {
      // API not reachable — fall back to a local dev session so the UI stays usable
      const devUser: User = {
        id: "dev-user",
        email: "dev@james.local",
        name: "Developer",
        executionMode: "direct",
        personalityId: null,
      };
      setAuth("dev-token", devUser);
    } finally {
      loading.value = false;
    }
  }

  async function refreshTokens() {
    const rt = refreshToken.value;
    if (!rt) return false;
    try {
      const data = await api.post<{ token: string; refreshToken: string }>(
        "/api/auth/refresh",
        {
          refresh_token: rt,
        },
      );
      token.value = data.token;
      refreshToken.value = data.refreshToken;
      localStorage.setItem("auth_token", data.token);
      localStorage.setItem("refresh_token", data.refreshToken);
      api.setToken(data.token);
      return true;
    } catch {
      logout();
      return false;
    }
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
    refreshTokens,
  };
});
