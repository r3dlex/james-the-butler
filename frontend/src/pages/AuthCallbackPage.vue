<template>
  <div
    class="flex h-screen items-center justify-center"
    style="background: var(--color-navy-deep)"
  >
    <div class="flex flex-col items-center gap-4">
      <img src="/logo-light.svg" alt="" width="48" height="48" class="opacity-60" />
      <p class="text-sm" style="color: var(--color-text-dim)">
        {{ message }}
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores/auth";
import { api } from "@/services/api";

const router = useRouter();
const auth = useAuthStore();
const message = ref("Signing you in…");

onMounted(async () => {
  const params = new URLSearchParams(window.location.search);
  const token = params.get("token");
  const refresh = params.get("refresh");
  const error = params.get("error");

  if (error) {
    message.value = `Sign-in failed: ${decodeURIComponent(error)}`;
    setTimeout(() => router.push("/login"), 3000);
    return;
  }

  if (!token) {
    message.value = "No token received. Redirecting…";
    setTimeout(() => router.push("/login"), 2000);
    return;
  }

  // Fetch the user profile with the new token
  api.setToken(token);
  try {
    const data = await api.get<{ user: typeof auth.user }>("/api/auth/me");
    auth.setAuth(token, data.user!, refresh ?? undefined);
    router.replace("/sessions");
  } catch {
    message.value = "Failed to load profile. Redirecting…";
    setTimeout(() => router.push("/login"), 2000);
  }
});
</script>
