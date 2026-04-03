import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { api } from "@/services/api";
import type { Session, CreateSessionPayload } from "@/types/session";
import { useProviderStore } from "@/stores/providers";
import { generateSessionName } from "@/utils/sessionNames";

export const useSessionStore = defineStore("sessions", () => {
  const sessions = ref<Session[]>([]);
  const activeSessionId = ref<string | null>(null);
  const loading = ref(false);
  const creating = ref(false);
  const createError = ref<string | null>(null);

  const canCreateSession = computed(() => {
    const providerStore = useProviderStore();
    return providerStore.providers.length > 0;
  });

  const activeSession = computed(
    () => sessions.value.find((s) => s.id === activeSessionId.value) ?? null,
  );

  // Return a sortable timestamp from any session, falling back gracefully when
  // updatedAt / createdAt are missing, empty, or invalid (e.g. backend skew).
  function sessionTimestamp(s: Session): number {
    const raw = s.updatedAt || s.createdAt || "";
    const t = raw ? new Date(raw).getTime() : NaN;
    return isNaN(t) ? 0 : t; // push undated sessions to the bottom
  }

  const sortedSessions = computed(() =>
    [...sessions.value].sort(
      (a, b) => sessionTimestamp(b) - sessionTimestamp(a),
    ),
  );

  async function fetchSessions() {
    loading.value = true;
    try {
      const data = await api.get<{ sessions: Session[] }>("/api/sessions");
      sessions.value = data.sessions;
    } catch {
      // fall through — sessions stay empty in dev mode without backend
    } finally {
      loading.value = false;
    }
  }

  function createLocalSession(payload: CreateSessionPayload): Session {
    const now = new Date().toISOString();
    const providedName = payload.name?.trim();
    const session: Session = {
      id: `local-${Date.now()}`,
      name: providedName || generateSessionName(),
      nameSetByUser: !!providedName,
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
    createError.value = null;

    const providerStore = useProviderStore();
    if (providerStore.providers.length === 0) {
      createError.value =
        "No connected provider found. Please go to Settings > Models to configure and test a provider.";
      return null;
    }

    creating.value = true;
    // Always send a name — generate an interesting default when none is provided
    const resolvedName = payload.name?.trim() || generateSessionName();
    try {
      const data = await api.post<{ session: Session }>("/api/sessions", {
        name: resolvedName,
        agent_type: payload.agentType,
        host_id: payload.hostId,
        project_id: payload.projectId,
        personality_id: payload.personalityId,
        execution_mode: payload.executionMode,
        keep_intermediates: payload.keepIntermediates,
        working_directories: payload.workingDirectories ?? [],
      });
      // Mark as not user-set when the name was auto-generated
      const session = {
        ...data.session,
        nameSetByUser: !!payload.name?.trim(),
      };
      sessions.value.unshift(session);
      return session;
    } catch {
      // API not available — create locally for dev mode
      return createLocalSession({ ...payload, name: resolvedName });
    } finally {
      creating.value = false;
    }
  }

  function autoNameSession(sessionId: string, firstMessage: string) {
    const session = sessions.value.find((s) => s.id === sessionId);
    if (!session || session.nameSetByUser) return;

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

  async function renameSession(sessionId: string, newName: string) {
    const session = sessions.value.find((s) => s.id === sessionId);
    if (!session) return;
    const trimmed = newName.trim();
    session.name = trimmed;
    session.nameSetByUser = true;
    session.updatedAt = new Date().toISOString();
    // Persist to backend
    try {
      await api.put(`/api/sessions/${sessionId}`, { name: trimmed });
    } catch {
      // ignore when backend is unavailable (dev mode)
    }
  }

  async function updateExecutionMode(
    sessionId: string,
    mode: import("@/types/session").ExecutionMode,
  ) {
    const session = sessions.value.find((s) => s.id === sessionId);
    if (!session) return;
    session.executionMode = mode;
    session.updatedAt = new Date().toISOString();
    try {
      await api.put(`/api/sessions/${sessionId}`, { executionMode: mode });
    } catch {
      // ignore when backend is unavailable
    }
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

  async function suspendSession(id: string) {
    const data = await api.post<{ session: Session }>(
      `/api/sessions/${id}/suspend`,
    );
    updateSession(data.session);
  }

  async function resumeSession(id: string) {
    const data = await api.post<{ session: Session }>(
      `/api/sessions/${id}/resume`,
    );
    updateSession(data.session);
  }

  async function terminateSession(id: string) {
    const data = await api.post<{ session: Session }>(
      `/api/sessions/${id}/terminate`,
    );
    updateSession(data.session);
  }

  return {
    sessions,
    activeSessionId,
    activeSession,
    sortedSessions,
    loading,
    creating,
    createError,
    canCreateSession,
    fetchSessions,
    createSession,
    createLocalSession,
    deleteSession,
    setActive,
    updateSession,
    autoNameSession,
    renameSession,
    updateExecutionMode,
    suspendSession,
    resumeSession,
    terminateSession,
  };
});
