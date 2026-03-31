import { defineStore } from "pinia";
import { ref } from "vue";
import type { Channel } from "phoenix";
import { getSocket, connectSocket, disconnectSocket } from "@/services/phoenix";

export type SocketStatus =
  | "disconnected"
  | "connecting"
  | "connected"
  | "error";

export const useSocketStore = defineStore("socket", () => {
  const status = ref<SocketStatus>("disconnected");
  const channels = ref<Map<string, Channel>>(new Map());

  function connect() {
    const socket = getSocket();

    socket.onOpen(() => {
      status.value = "connected";
    });

    socket.onClose(() => {
      status.value = "disconnected";
    });

    socket.onError(() => {
      status.value = "error";
    });

    connectSocket();
    status.value = "connecting";
  }

  function disconnect() {
    channels.value.forEach((ch) => ch.leave());
    channels.value.clear();
    disconnectSocket();
    status.value = "disconnected";
  }

  function joinChannel(
    topic: string,
    params: Record<string, unknown> = {},
  ): Channel {
    if (channels.value.has(topic)) {
      return channels.value.get(topic)!;
    }

    const socket = getSocket();
    const channel = socket.channel(topic, params);

    channel
      .join()
      .receive("ok", () => {
        channels.value.set(topic, channel);
      })
      .receive("error", () => {
        channels.value.delete(topic);
      });

    channels.value.set(topic, channel);
    return channel;
  }

  function leaveChannel(topic: string) {
    const ch = channels.value.get(topic);
    if (ch) {
      ch.leave();
      channels.value.delete(topic);
    }
  }

  return { status, channels, connect, disconnect, joinChannel, leaveChannel };
});
