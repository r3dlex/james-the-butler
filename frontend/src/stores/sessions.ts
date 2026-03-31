import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { api } from "@/services/api";
import type { Session, CreateSessionPayload } from "@/types/session";

export const useSessionStore = defineStore("sessions", () => {
  const sessions = ref<Session[]>([]);
  const activeSessionId = ref<string | null>(null);
  const loading = ref(false);
  const creating = ref(false);

  const activeSession = computed(
    () => sessions.value.find((s) => s.id === activeSessionId.value) ?? null,
  );

  const sortedSessions = computed(() =>
    [...sessions.value].sort(
      (a, b) =>
        new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime(),
    ),
  );

  async function fetchSessions() {
    loading.value = true;
    try {
      const data = await api.get<{ data: Session[] }>("/api/sessions");
      sessions.value = data.data;
    } catch {
      // TODO: error handling
    } finally {
      loading.value = false;
    }
  }

  function createLocalSession(payload: CreateSessionPayload): Session {
    const now = new Date().toISOString();
    const hasUserName = !!payload.name?.trim();
    const session: Session = {
      id: `local-${Date.now()}`,
      name: hasUserName ? payload.name!.trim() : "New Session",
      nameSetByUser: hasUserName,
      agentType: payload.agentType,
      hostId: payload.hostId,
      projectId: payload.projectId ?? null,
      status: "active",
      executionMode: payload.executionMode ?? "direct",
      personalityId: payload.personalityId ?? null,
      workingDirectories: payload.workingDirectories ?? [],
      mcpServers: payload.mcpServers ?? [],
      keepIntermediates: payload.keepIntermediates ?? false,
      tokenCount: 0,
      tokenCost: 0,
      createdAt: now,
      updatedAt: now,
    };
    sessions.value.unshift(session);
    return session;
  }

  async function createSession(
    payload: CreateSessionPayload,
  ): Promise<Session | null> {
    creating.value = true;
    try {
      const data = await api.post<{ data: Session }>("/api/sessions", payload);
      sessions.value.unshift(data.data);
      return data.data;
    } catch {
      // API not available — create locally for dev mode
      return createLocalSession(payload);
    } finally {
      creating.value = false;
    }
  }

  /** Auto-generate a session title from the first user message (if not user-set). */
  function autoNameSession(sessionId: string, firstMessage: string) {
    const session = sessions.value.find((s) => s.id === sessionId);
    if (!session || session.nameSetByUser) return;

    // Truncate to a clean title: first sentence or first 60 chars
    let title = firstMessage.trim();
    const sentenceEnd = title.search(/[.!?]\s/);
    if (sentenceEnd > 0 && sentenceEnd < 60) {
      title = title.slice(0, sentenceEnd + 1);
    } else if (title.length > 60) {
      title = title.slice(0, 57).trimEnd() + "...";
    }
    session.name = title;
    session.updatedAt = new Date().toISOString();
  }

  /** User explicitly renames a session — locks the name from auto-updates. */
  function renameSession(sessionId: string, newName: string) {
    const session = sessions.value.find((s) => s.id === sessionId);
    if (!session) return;
    session.name = newName.trim();
    session.nameSetByUser = true;
    session.updatedAt = new Date().toISOString();
  }

  async function deleteSession(id: string) {
    try {
      await api.delete(`/api/sessions/${id}`);
    } catch {
      // ok in dev mode
    }
    sessions.value = sessions.value.filter((s) => s.id !== id);
    if (activeSessionId.value === id) activeSessionId.value = null;
  }

  function setActive(id: string | null) {
    activeSessionId.value = id;
  }

  function updateSession(updated: Session) {
    const idx = sessions.value.findIndex((s) => s.id === updated.id);
    if (idx !== -1) sessions.value[idx] = updated;
  }

  return {
    sessions,
    activeSessionId,
    activeSession,
    sortedSessions,
    loading,
    creating,
    fetchSessions,
    createSession,
    createLocalSession,
    deleteSession,
    setActive,
    updateSession,
    autoNameSession,
    renameSession,
  };
});
