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

  /**
   * Normalises the `content` field of a server message.
   * The backend may send content as a plain string at runtime even though
   * the TypeScript type says ContentBlock[].  We always store ContentBlock[].
   */
  function normalizeMessage(message: Message): Message {
    const raw = message.content as unknown;
    if (Array.isArray(raw)) return message; // already ContentBlock[]
    if (typeof raw === "string" && raw.length > 0) {
      return { ...message, content: [{ type: "text", text: raw }] };
    }
    return { ...message, content: [] };
  }

  function appendMessage(sessionId: string, message: Message) {
    const msgs = messagesBySession.value.get(sessionId) ?? [];
    msgs.push(normalizeMessage(message));
    messagesBySession.value.set(sessionId, msgs);
  }

  /**
   * Idempotently inserts a server-confirmed message:
   * 1. If the same message ID already exists, update it in place (re-delivery guard).
   * 2. If a temp-* message with the same role exists, replace it.
   * 3. Otherwise append.
   * Content is always normalised to ContentBlock[].
   */
  function replaceOrAppendMessage(sessionId: string, message: Message) {
    const msg = normalizeMessage(message);
    const msgs = messagesBySession.value.get(sessionId) ?? [];

    // Guard: same ID already in list → update in place, do not duplicate
    const existingIdx = msgs.findIndex((m) => m.id === msg.id);
    if (existingIdx !== -1) {
      msgs.splice(existingIdx, 1, msg);
      messagesBySession.value.set(sessionId, msgs);
      return;
    }

    // Replace the first optimistic temp message with matching role
    const tempIdx = msgs.findIndex(
      (m) => m.id.startsWith("temp-") && m.role === msg.role,
    );
    if (tempIdx !== -1) {
      msgs.splice(tempIdx, 1, msg);
      messagesBySession.value.set(sessionId, msgs);
    } else {
      msgs.push(msg);
      messagesBySession.value.set(sessionId, msgs);
    }
  }

  // Buffer for batching rapid streaming chunks before committing to reactive state.
  let _pendingBuffer = "";
  let _flushTimer: ReturnType<typeof setTimeout> | null = null;

  function _flushBuffer() {
    if (_flushTimer !== null) {
      clearTimeout(_flushTimer);
      _flushTimer = null;
    }
    if (_pendingBuffer === "") return;
    // Collapse 3+ consecutive newlines to exactly 2.
    const normalised = _pendingBuffer.replace(/\n{3,}/g, "\n\n");
    streamingContent.value = normalised;
    streamingBlocks.value = [{ type: "text", text: normalised }];
  }

  function startStreaming(sessionId: string) {
    _pendingBuffer = "";
    if (_flushTimer !== null) {
      clearTimeout(_flushTimer);
      _flushTimer = null;
    }
    streamingSessionId.value = sessionId;
    streamingContent.value = "";
    streamingBlocks.value = [{ type: "text", text: "" }];
  }

  function appendStreamChunk(chunk: string) {
    _pendingBuffer += chunk;
    if (_flushTimer === null) {
      _flushTimer = setTimeout(() => {
        _flushTimer = null;
        _flushBuffer();
      }, 50);
    }
  }

  function stopStreaming() {
    // Discard any pending buffer — the assistant message has been committed.
    _pendingBuffer = "";
    if (_flushTimer !== null) {
      clearTimeout(_flushTimer);
      _flushTimer = null;
    }
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
