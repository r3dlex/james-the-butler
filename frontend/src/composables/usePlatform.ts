import { computed } from "vue";

export function usePlatform() {
  const isDesktop = computed(() => "__TAURI__" in window);
  const isWeb = computed(() => !isDesktop.value);

  return { isDesktop, isWeb };
}
