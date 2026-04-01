// @vitest-environment happy-dom
import { describe, it, expect } from "vitest";

/**
 * Router configuration tests.
 *
 * We import the raw route definitions rather than the router instance so we
 * avoid side-effects such as beforeEach guards that call useAuthStore (which
 * requires a Pinia instance to be active).  The important structural
 * properties are entirely readable from the routes array.
 */

// Import the module — we use dynamic import to keep things lazy and avoid
// triggering the router's beforeEach guard during module init.
const getRoutes = async () => {
  const mod = await import("../router/index");
  return mod.default.getRoutes();
};

describe("Router configuration", () => {
  it("router module is importable", async () => {
    const mod = await import("../router/index");
    expect(mod.default).toBeDefined();
  });

  it("has routes defined", async () => {
    const routes = await getRoutes();
    expect(routes.length).toBeGreaterThan(0);
  });

  it("has a /login route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/login");
  });

  it("has a /sessions route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/sessions");
  });

  it("has a /sessions/:id route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/sessions/:id");
  });

  it("has a /projects route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/projects");
  });

  it("has a /tasks route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/tasks");
  });

  it("has a /settings/models route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/settings/models");
  });

  it("has a /settings/security route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/settings/security");
  });

  it("has a /hosts route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/hosts");
  });

  it("/login route is marked as public (meta.public === true)", async () => {
    const routes = await getRoutes();
    const login = routes.find((r) => r.path === "/login");
    expect(login).toBeDefined();
    expect(login?.meta?.public).toBe(true);
  });

  it("/auth/callback route is marked as public", async () => {
    const routes = await getRoutes();
    const cb = routes.find((r) => r.path === "/auth/callback");
    expect(cb).toBeDefined();
    expect(cb?.meta?.public).toBe(true);
  });

  it("/sessions route is NOT marked as public", async () => {
    const routes = await getRoutes();
    const sessions = routes.find((r) => r.path === "/sessions");
    expect(sessions).toBeDefined();
    expect(sessions?.meta?.public).toBeFalsy();
  });

  it("has a / root route that redirects to /sessions", async () => {
    const routes = await getRoutes();
    const root = routes.find((r) => r.path === "/");
    expect(root).toBeDefined();
    expect((root as { redirect?: string })?.redirect).toBe("/sessions");
  });

  it("has a /settings redirect to /settings/models", async () => {
    const routes = await getRoutes();
    const settings = routes.find((r) => r.path === "/settings");
    expect(settings).toBeDefined();
    expect((settings as { redirect?: string })?.redirect).toBe(
      "/settings/models",
    );
  });

  it("has an /openclaw route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/openclaw");
  });

  it("has a /mobile-setup route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/mobile-setup");
  });

  it("has a /memory route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/memory");
  });

  it("has a /sessions/:id/sub/:subId route", async () => {
    const routes = await getRoutes();
    const paths = routes.map((r) => r.path);
    expect(paths).toContain("/sessions/:id/sub/:subId");
  });
});
