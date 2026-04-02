/**
 * Vitest global setup: bridge browser globals from the happy-dom Window to
 * the Node.js globalThis so unqualified `localStorage` calls in source modules
 * work during tests.
 *
 * Vitest's happy-dom environment attaches globals to `window` via a getter
 * proxy on `global`, but only for keys explicitly in its KEYS list. The
 * `localStorage` and `sessionStorage` properties are NOT in that list, so
 * they remain undefined in the Node global scope.  We fix this here once the
 * environment window exists.
 */

if (typeof window !== "undefined") {
  if (typeof globalThis.localStorage === "undefined" && window.localStorage) {
    (globalThis as unknown as Record<string, unknown>).localStorage =
      window.localStorage;
  }
  if (
    typeof globalThis.sessionStorage === "undefined" &&
    window.sessionStorage
  ) {
    (globalThis as unknown as Record<string, unknown>).sessionStorage =
      window.sessionStorage;
  }
}
