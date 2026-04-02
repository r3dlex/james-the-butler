import { defineStore } from "pinia";
import { ref } from "vue";
import { api } from "@/services/api";
import type { Message, ContentBlock, PlannerStep } from "@/types/message";

export const useMessageStore = defineStore("messages", () => {
  const messagesBySession = ref<Map<string, Message[]>>(new Map());
  const streamingSessionId = ref<string | null>(null);
  const streamingContent = ref("");
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
      // Do NOT push to the list here — the caller already added an optimistic
      // temp message. Return the server message for reference only.
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

  /**
   * If a temp message (id starts with "temp-") with the same role exists,
   * replace it with the incoming message; otherwise append normally.
   */
  function replaceOrAppendMessage(sessionId: string, message: Message) {
    const msgs = messagesBySession.value.get(sessionId) ?? [];
    const tempIdx = msgs.findIndex(
      (m) => m.id.startsWith("temp-") && m.role === message.role,
    );
    if (tempIdx !== -1) {
      msgs.splice(tempIdx, 1, message);
      messagesBySession.value.set(sessionId, msgs);
    } else {
      appendMessage(sessionId, message);
    }
  }

  function startStreaming(sessionId: string) {
    streamingSessionId.value = sessionId;
    streamingContent.value = "";
    streamingBlocks.value = [{ type: "text", text: "" }];
  }

  function appendStreamChunk(chunk: string) {
    streamingContent.value += chunk;
    streamingBlocks.value = [{ type: "text", text: streamingContent.value }];
  }

  function stopStreaming() {
    streamingSessionId.value = null;
    streamingContent.value = "";
    streamingBlocks.value = [];
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
    streamingContent,
    streamingBlocks,
    plannerSteps,
    loading,
    getMessages,
    fetchMessages,
    setMessages,
    sendMessage,
    appendMessage,
    replaceOrAppendMessage,
    startStreaming,
    appendStreamChunk,
    stopStreaming,
    setStreamingState,
    setPlannerSteps,
    clearSession,
  };
});
