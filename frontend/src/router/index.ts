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
      path: "/openclaw",
      component: () => import("@/pages/OpenClawActivityPage.vue"),
    },
    {
      path: "/mobile-setup",
      component: () => import("@/pages/MobileSetupPage.vue"),
    },
    {
      path: "/settings",
      redirect: "/settings/models",
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
      path: "/settings/security",
      component: () => import("@/pages/settings/SettingsSecurityPage.vue"),
    },
    {
      path: "/settings/telegram",
      component: () => import("@/pages/settings/SettingsTelegramPage.vue"),
    },
    {
      path: "/settings/desktop-control",
      component: () =>
        import("@/pages/settings/SettingsDesktopControlPage.vue"),
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

router.beforeEach((to) => {
  if (to.meta.public) return true;

  const auth = useAuthStore();
  if (!auth.isAuthenticated) {
    return { path: "/login", query: { redirect: to.fullPath } };
  }
  return true;
});

export default router;
