import { defineStore } from "pinia";
import { ref } from "vue";
import { api } from "@/services/api";
import type { Message, ContentBlock, PlannerStep } from "@/types/message";

export const useMessageStore = defineStore("messages", () => {
  const messagesBySession = ref<Map<string, Message[]>>(new Map());
  const streamingSessionId = ref<string | null>(null);
  const streamingBlocks = ref<ContentBlock[]>([]);
  const plannerSteps = ref<PlannerStep[]>([]);
  const loading = ref(false);

  function getMessages(sessionId: string): Message[] {
    return messagesBySession.value.get(sessionId) ?? [];
  }

  // Messages are loaded from the channel join payload (see useSessionChannel).
  // This method provides a fallback HTTP load if needed.
  async function fetchMessages(sessionId: string) {
    loading.value = true;
    try {
      // Backend returns messages inside session detail for simple access
      const data = await api.get<{ session: { messageCount: number } }>(
        `/api/sessions/${sessionId}`,
      );
      // If no cached messages, set empty array so the view renders
      if (!messagesBySession.value.has(sessionId)) {
        messagesBySession.value.set(sessionId, []);
      }
      return data;
    } catch {
      if (!messagesBySession.value.has(sessionId)) {
        messagesBySession.value.set(sessionId, []);
      }
    } finally {
      loading.value = false;
    }
  }

  // Called when the session channel join returns the message history
  function setMessages(sessionId: string, messages: Message[]) {
    messagesBySession.value.set(sessionId, messages);
  }

  async function sendMessage(
    sessionId: string,
    content: string,
    _attachments: string[] = [],
  ) {
    try {
      const data = await api.post<{ message: Message }>(
        `/api/sessions/${sessionId}/messages`,
        { content },
      );
      const msgs = messagesBySession.value.get(sessionId) ?? [];
      msgs.push(data.message);
      messagesBySession.value.set(sessionId, msgs);
      return data.message;
    } catch {
      return null;
    }
  }

  function appendMessage(sessionId: string, message: Message) {
    const msgs = messagesBySession.value.get(sessionId) ?? [];
    msgs.push(message);
    messagesBySession.value.set(sessionId, msgs);
  }

  function setStreamingState(
    sessionId: string | null,
    blocks: ContentBlock[] = [],
  ) {
    streamingSessionId.value = sessionId;
    streamingBlocks.value = blocks;
  }

  function setPlannerSteps(steps: PlannerStep[]) {
    plannerSteps.value = steps;
  }

  function clearSession(sessionId: string) {
    messagesBySession.value.delete(sessionId);
  }

  return {
    messagesBySession,
    streamingSessionId,
    streamingBlocks,
    plannerSteps,
    loading,
    getMessages,
    fetchMessages,
    setMessages,
    sendMessage,
    appendMessage,
    setStreamingState,
    setPlannerSteps,
    clearSession,
  };
});
