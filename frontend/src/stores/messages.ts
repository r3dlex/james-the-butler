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

  async function fetchMessages(sessionId: string, page = 1) {
    loading.value = true;
    try {
      const data = await api.get<{ data: Message[] }>(
        `/api/sessions/${sessionId}/messages?page=${page}`,
      );
      const existing = messagesBySession.value.get(sessionId) ?? [];
      if (page === 1) {
        messagesBySession.value.set(sessionId, data.data);
      } else {
        messagesBySession.value.set(sessionId, [...data.data, ...existing]);
      }
    } catch {
      // TODO: error handling
    } finally {
      loading.value = false;
    }
  }

  async function sendMessage(
    sessionId: string,
    content: string,
    attachments: string[] = [],
  ) {
    try {
      const data = await api.post<{ data: Message }>(
        `/api/sessions/${sessionId}/messages`,
        { content, attachments },
      );
      const msgs = messagesBySession.value.get(sessionId) ?? [];
      msgs.push(data.data);
      messagesBySession.value.set(sessionId, msgs);
      return data.data;
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
    sendMessage,
    appendMessage,
    setStreamingState,
    setPlannerSteps,
    clearSession,
  };
});
