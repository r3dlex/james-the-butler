import { ref, onUnmounted } from "vue";
import type { Channel } from "phoenix";
import { getSocket } from "@/services/phoenix";

export function usePhoenixChannel(topic: string) {
  const channel = ref<Channel | null>(null);
  const joined = ref(false);
  const error = ref<string | null>(null);

  function join(params: Record<string, unknown> = {}) {
    const socket = getSocket();
    const ch = socket.channel(topic, params);

    ch.join()
      .receive("ok", () => {
        joined.value = true;
        error.value = null;
      })
      .receive("error", (resp: unknown) => {
        error.value = String(resp);
        joined.value = false;
      });

    channel.value = ch;
    return ch;
  }

  function leave() {
    channel.value?.leave();
    channel.value = null;
    joined.value = false;
  }

  function on(event: string, callback: (payload: unknown) => void) {
    channel.value?.on(event, callback);
  }

  function push(event: string, payload: unknown = {}) {
    return channel.value?.push(event, payload);
  }

  onUnmounted(() => {
    leave();
  });

  return { channel, joined, error, join, leave, on, push };
}
