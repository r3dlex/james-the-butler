import { watch } from "vue";
import { usePhoenixChannel } from "./usePhoenixChannel";
import { useMessageStore } from "@/stores/messages";
import { useTaskStore } from "@/stores/tasks";
import type { Message } from "@/types/message";
import type { Task } from "@/types/task";

/**
 * Joins the Phoenix `session:<id>` channel for a given session and wires
 * up real-time events to the message and task stores.
 *
 * The channel join response includes the message history so we don't need
 * a separate HTTP call to load messages.
 */
export function useSessionChannel(sessionId: () => string | null) {
  const { channel, joined, error, join, leave, on } = usePhoenixChannel(
    `session:${sessionId()}`,
  );

  const messageStore = useMessageStore();
  const taskStore = useTaskStore();

  function connect(id: string) {
    const ch = join();

    // Load message history from channel join reply
    ch.join()
      .receive("ok", (resp: { messages: Message[] }) => {
        messageStore.setMessages(id, resp.messages ?? []);
      });

    // New message pushed from backend (user echo or assistant response)
    on("message:new", (payload: unknown) => {
      messageStore.appendMessage(id, payload as Message);
    });

    // Streaming assistant text chunk
    on("message:chunk", (payload: unknown) => {
      const { content } = payload as { content: string };
      messageStore.setStreamingState(id, [{ type: "text", text: content }] as never);
    });

    // Task status update
    on("task:updated", (payload: unknown) => {
      taskStore.updateTask(payload as Task);
    });

    // Artifact created
    on("artifact:created", (_payload: unknown) => {
      // artifacts not yet tracked in a store — no-op for now
    });
  }

  // Re-join when the session ID changes
  watch(
    () => sessionId(),
    (id) => {
      leave();
      if (id) connect(id);
    },
    { immediate: true },
  );

  return { channel, joined, error, leave };
}
