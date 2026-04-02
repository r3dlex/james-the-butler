import { onUnmounted, getCurrentInstance } from "vue";
import { useProviderStore } from "@/stores/providers";
import type { ProviderConfig } from "@/types/provider";

/** Re-test a connected provider if its last test is older than this threshold. */
const STALE_THRESHOLD_MS = 25 * 60 * 1000; // 25 minutes

/** How often to run the heartbeat check. */
const HEARTBEAT_INTERVAL_MS = 2 * 60 * 1000; // 2 minutes

function isStale(provider: ProviderConfig): boolean {
  if (!provider.lastTestedAt) return true;
  const ageMs = Date.now() - new Date(provider.lastTestedAt).getTime();
  return ageMs > STALE_THRESHOLD_MS;
}

/**
 * Composable that periodically re-tests all `connected` providers that have
 * become stale (last tested > 25 minutes ago).
 *
 * Only re-tests providers that are currently `connected` — does not touch
 * `failed` or `untested` providers (those require explicit user action).
 *
 * Usage:
 *   const { start, stop } = useProviderHeartbeat();
 *   onMounted(start);   // or call start() after auth
 *   onUnmounted(stop);  // automatically called if used inside a component
 */
export function useProviderHeartbeat() {
  const providerStore = useProviderStore();
  let timer: ReturnType<typeof setInterval> | null = null;

  function tick(): void {
    const staleConnected = providerStore.providers.filter(
      (p) => p.status === "connected" && isStale(p),
    );
    for (const p of staleConnected) {
      providerStore.testConnection(p.id).catch(() => {
        // Silently absorb — status is updated inside testConnection
      });
    }
  }

  function start(): void {
    if (timer !== null) return; // already running
    timer = setInterval(tick, HEARTBEAT_INTERVAL_MS);
  }

  function stop(): void {
    if (timer !== null) {
      clearInterval(timer);
      timer = null;
    }
  }

  // Automatically stop when the component that called this composable unmounts.
  // Guard with getCurrentInstance() so the composable can safely be called
  // outside of a component setup context (e.g. App.vue top-level, tests).
  if (getCurrentInstance()) {
    onUnmounted(stop);
  }

  return { start, stop, tick };
}
