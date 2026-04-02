import { ref, onMounted, onUnmounted } from "vue";

/**
 * Returns a reactive logo src that switches between light and dark variants
 * based on the current data-theme attribute on <html>.
 *
 * Dark mode → /logo-light.svg (white bubble on dark background)
 * Light mode → /logo.svg (dark navy bubble on light background)
 */
export function useLogoSrc() {
  const getLogoSrc = () =>
    document.documentElement.getAttribute("data-theme") === "light"
      ? "/logo.svg"
      : "/logo-light.svg";

  const logoSrc = ref(getLogoSrc());

  let observer: MutationObserver | null = null;

  onMounted(() => {
    logoSrc.value = getLogoSrc();
    observer = new MutationObserver(() => {
      logoSrc.value = getLogoSrc();
    });
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"],
    });
  });

  onUnmounted(() => {
    observer?.disconnect();
  });

  return logoSrc;
}
