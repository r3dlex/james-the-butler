import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "@/stores/auth";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      redirect: "/sessions",
    },
    {
      path: "/login",
      component: () => import("@/pages/LoginPage.vue"),
      meta: { public: true },
    },
    {
      path: "/auth/callback",
      component: () => import("@/pages/AuthCallbackPage.vue"),
      meta: { public: true },
    },
    {
      path: "/sessions",
      component: () => import("@/pages/SessionListPage.vue"),
    },
    {
      path: "/sessions/:id",
      component: () => import("@/pages/SessionView.vue"),
    },
    {
      path: "/sessions/:id/sub/:subId",
      component: () => import("@/pages/SubSessionView.vue"),
    },
    {
      path: "/projects",
      component: () => import("@/pages/ProjectListPage.vue"),
    },
    {
      path: "/projects/new",
      component: () => import("@/pages/ProjectListPage.vue"),
      props: { autoCreate: true },
    },
    {
      path: "/projects/:id",
      component: () => import("@/pages/ProjectView.vue"),
    },
    {
      path: "/projects/:id/settings",
      component: () => import("@/pages/ProjectSettingsPage.vue"),
    },
    {
      path: "/tasks",
      component: () => import("@/pages/TaskListPage.vue"),
    },
    {
      path: "/memory",
      component: () => import("@/pages/MemoryPage.vue"),
    },
    {
      path: "/hosts",
      component: () => import("@/pages/HostListPage.vue"),
    },
    {
      path: "/hosts/:id",
      component: () => import("@/pages/HostDetailPage.vue"),
    },
    {
      path: "/mobile-setup",
      component: () => import("@/pages/MobileSetupPage.vue"),
    },

    // ── Settings ──────────────────────────────────────────────────────────────
    {
      // Default redirect goes to General (not Models) so there's always a
      // "home" settings page that isn't provider-specific.
      path: "/settings",
      redirect: "/settings/general",
    },
    {
      path: "/settings/general",
      component: () => import("@/pages/settings/SettingsGeneralPage.vue"),
    },
    {
      path: "/settings/models",
      component: () => import("@/pages/settings/SettingsModelsPage.vue"),
    },
    {
      path: "/settings/mcp",
      component: () => import("@/pages/settings/SettingsMcpPage.vue"),
    },
    {
      path: "/settings/directories",
      component: () => import("@/pages/settings/SettingsDirectoriesPage.vue"),
    },
    {
      path: "/settings/skills",
      component: () => import("@/pages/settings/SettingsSkillsPage.vue"),
    },
    {
      path: "/settings/personality",
      component: () => import("@/pages/settings/SettingsPersonalityPage.vue"),
    },
    {
      path: "/settings/execution-mode",
      component: () => import("@/pages/settings/SettingsExecutionModePage.vue"),
    },
    {
      path: "/settings/memory",
      component: () => import("@/pages/settings/SettingsMemoryPage.vue"),
    },
    {
      path: "/settings/telegram",
      component: () => import("@/pages/settings/SettingsTelegramPage.vue"),
    },
    {
      path: "/settings/billing",
      component: () => import("@/pages/settings/SettingsBillingPage.vue"),
    },
    {
      path: "/settings/plugins",
      component: () => import("@/pages/settings/SettingsPluginsPage.vue"),
    },
    {
      path: "/settings/hooks",
      component: () => import("@/pages/settings/SettingsHooksPage.vue"),
    },
    {
      path: "/settings/channels",
      component: () => import("@/pages/settings/SettingsChannelsPage.vue"),
    },
  ],
});

// ── Auth guard ────────────────────────────────────────────────────────────────
router.beforeEach((to) => {
  if (to.meta.public) return true;

  const auth = useAuthStore();
  if (!auth.isAuthenticated) {
    return { path: "/login", query: { redirect: to.fullPath } };
  }
  return true;
});

// ── Background provider health check when entering Settings ──────────────────
// Re-tests any provider that has never been tested OR whose last test is
// older than 30 minutes. Runs silently in the background.
router.afterEach((to, from) => {
  // Only trigger when actually navigating *into* settings (not within it)
  if (!to.path.startsWith("/settings")) return;
  if (from.path.startsWith("/settings")) return;

  // Lazy-import avoids circular dependency issues
  import("@/stores/providers").then(({ useProviderStore }) => {
    const providerStore = useProviderStore();
    const THIRTY_MIN_MS = 30 * 60 * 1000;

    providerStore.providers.forEach((p) => {
      const isStale =
        !p.lastTestedAt ||
        Date.now() - new Date(p.lastTestedAt).getTime() > THIRTY_MIN_MS;

      if (p.status === "untested" || (p.status === "connected" && isStale)) {
        providerStore.testConnection(p.id).catch(() => {});
      }
    });
  });
});

export default router;
