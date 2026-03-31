import { ref, onMounted, onUnmounted } from "vue";
import { getSocket } from "@/services/phoenix";

export function useKeepAlive() {
  const connected = ref(false);
  let interval: ReturnType<typeof setInterval> | null = null;

  function check() {
    const socket = getSocket();
    connected.value = socket.isConnected();
  }

  onMounted(() => {
    check();
    interval = setInterval(check, 5000);
  });

  onUnmounted(() => {
    if (interval) clearInterval(interval);
  });

  return { connected };
}
