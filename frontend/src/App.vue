<template>
  <AppShell v-if="auth.isAuthenticated">
    <RouterView />
  </AppShell>
  <RouterView v-else />
</template>

<script setup lang="ts">
import { onMounted, watch } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores/auth";
import { useProviderStore } from "@/stores/providers";
import AppShell from "@/components/layout/AppShell.vue";

const auth = useAuthStore();
const providerStore = useProviderStore();
const router = useRouter();

// Redirect to /login whenever the user logs out from anywhere in the app
watch(
  () => auth.isAuthenticated,
  (authed) => {
    if (!authed) router.push("/login");
  },
);

onMounted(async () => {
  // Restore session from stored token; on failure, logout() is called internally
  await auth.fetchCurrentUser();

  // Pre-load providers so hasVerifiedProvider is accurate before first chat
  if (auth.isAuthenticated) {
    providerStore.fetchProviders().catch(() => {});
  }
});
</script>
