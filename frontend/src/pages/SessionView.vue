<template>
  <div class="flex h-full">
    <!-- Main chat area -->
    <div class="flex flex-1 flex-col overflow-hidden">
      <!-- Session header: title + host + paths + token cost -->
      <div
        class="flex shrink-0 items-center gap-3 border-b px-4 py-2"
        style="border-color: var(--color-border)"
      >
        <!-- Editable title -->
        <div class="min-w-0 shrink">
          <input
            v-if="editingTitle"
            ref="titleInputRef"
            v-model="titleDraft"
            class="max-w-48 rounded border bg-transparent px-2 py-0.5 text-sm font-medium outline-none focus:border-[var(--color-gold)]"
            style="border-color: var(--color-border); color: var(--color-text)"
            @keydown.enter="saveTitle"
            @keydown.escape="cancelEditTitle"
            @blur="saveTitle"
          />
          <button
            v-else
            class="flex max-w-48 items-center gap-1 truncate rounded px-2 py-0.5 text-sm font-medium transition-colors hover:bg-[var(--color-surface)]"
            style="color: var(--color-text)"
            :title="session?.name"
            @click="startEditTitle"
          >
            <span class="truncate">{{ session?.name ?? "New Session" }}</span>
            <span
              v-if="session && !session.nameSetByUser"
              class="shrink-0 text-xs italic"
              style="color: var(--color-text-dim)"
            >
              (auto)
            </span>
          </button>
        </div>

        <!-- Host badge -->
        <div
          class="flex items-center gap-1.5 rounded-md px-2 py-1"
          style="background: var(--color-surface)"
        >
          <span
            class="h-1.5 w-1.5 rounded-full"
            style="background: var(--color-risk-green)"
          />
          <span class="text-xs" style="color: var(--color-text-dim)">
            {{ session?.hostId ?? "primary" }}
          </span>
        </div>

        <!-- Token cost -->
        <div
          class="flex items-center gap-1 rounded-md px-2 py-1"
          style="background: var(--color-surface)"
        >
          <span
            class="flex h-4 w-4 items-center justify-center rounded-full text-xs font-bold"
            style="background: var(--color-gold); color: var(--color-navy-deep)"
          >
            $
          </span>
          <span
            class="text-xs tabular-nums"
            style="color: var(--color-text-dim)"
          >
            {{ sessionCost }}
          </span>
        </div>

        <!-- Queued messages badge -->
        <div
          v-if="sendQueue.length > 0"
          class="flex items-center gap-1 rounded-md px-2 py-1"
          style="background: var(--color-surface)"
        >
          <span class="text-xs" style="color: var(--color-gold)">
            {{ sendQueue.length }} queued
          </span>
        </div>
      </div>

      <!-- Messages -->
      <ChatMessageStream
        :messages="messages"
        :is-streaming="isStreaming"
        :streaming-text="streamingText"
      />

      <!-- Input + workspace panel -->
      <div class="shrink-0">
        <!-- Chat input — always enabled; messages queue when James is busy -->
        <ChatInput @send="handleSend" />

        <!-- Workspace & mode panel (Claude Desktop style) -->
        <div
          class="flex items-center gap-3 border-t px-4 py-2"
          style="border-color: var(--color-border)"
        >
          <!-- Working directories -->
          <div class="flex min-w-0 flex-1 flex-wrap items-center gap-1.5">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="12"
              height="12"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              class="shrink-0"
              style="color: var(--color-text-dim)"
            >
              <path
                d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"
              />
            </svg>
            <template v-if="session?.workingDirectories?.length">
              <span
                v-for="dir in session.workingDirectories"
                :key="dir"
                class="max-w-32 truncate rounded px-1.5 py-0.5 text-xs"
                style="
                  background: var(--color-surface);
                  color: var(--color-text-dim);
                "
                :title="dir"
              >
                {{ dir }}
              </span>
            </template>
            <span v-else class="text-xs" style="color: var(--color-text-dim)">
              No workspace
            </span>
          </div>

          <!-- Execution mode selector -->
          <div class="flex shrink-0 items-center gap-1.5">
            <span class="text-xs" style="color: var(--color-text-dim)">
              Mode:
            </span>
            <select
              :value="sessionModeChoice"
              class="rounded border bg-transparent px-2 py-0.5 text-xs outline-none focus:border-[var(--color-gold)]"
              style="
                border-color: var(--color-border);
                color: var(--color-text);
                background: var(--color-navy-deep);
              "
              @change="onModeChange"
            >
              <option value="user_default">User Default</option>
              <option value="direct">Direct</option>
              <option value="confirmed">Supervised</option>
            </select>
          </div>
        </div>
      </div>
    </div>

    <!-- Right: task panel -->
    <SessionActivityPanel
      :tasks="tasks"
      :planner-status="plannerStatus"
      @approve="handleApprove"
      @reject="handleReject"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from "vue";
import { useRoute } from "vue-router";
import { useSessionStore } from "@/stores/sessions";
import { useMessageStore } from "@/stores/messages";
import { useTaskStore } from "@/stores/tasks";
import { useSocketStore } from "@/stores/socket";
import { useTokenStore } from "@/stores/tokens";
import type { Message } from "@/types/message";
import type { ExecutionMode } from "@/types/session";
import SessionActivityPanel from "@/components/session/SessionActivityPanel.vue";
import ChatMessageStream from "@/components/session/ChatMessageStream.vue";
import ChatInput from "@/components/session/ChatInput.vue";

const SETTINGS_KEY = "james_general_settings";

const route = useRoute();
const sessionStore = useSessionStore();
const messageStore = useMessageStore();
const taskStore = useTaskStore();
const socketStore = useSocketStore();
const tokenStore = useTokenStore();

const sessionId = computed(() => route.params.id as string);
const session = computed(
  () => sessionStore.sessions.find((s) => s.id === sessionId.value) ?? null,
);
const messages = computed(() => messageStore.getMessages(sessionId.value));
const isStreaming = computed(
  () => messageStore.streamingSessionId === sessionId.value,
);
const streamingText = computed(() =>
  isStreaming.value ? messageStore.streamingContent : "",
);
const tasks = computed(() => taskStore.getTasksForSession(sessionId.value));

const sessionCost = computed(() => {
  const usage = tokenStore.getUsage(sessionId.value);
  return usage ? `$${usage.cost.toFixed(4)}` : "$0.00";
});

// ── Execution mode selector ──────────────────────────────────────────────────
// Shows "user_default" when the session's executionMode matches the persisted
// general setting, otherwise shows the overriding value.
const sessionModeChoice = computed<"direct" | "confirmed" | "user_default">(
  () => {
    if (!session.value) return "user_default";
    return session.value.executionMode ?? "user_default";
  },
);

function resolveDefaultMode(): ExecutionMode {
  try {
    const stored = localStorage.getItem(SETTINGS_KEY);
    if (stored) {
      const s = JSON.parse(stored) as { defaultExecutionMode?: string };
      if (s.defaultExecutionMode === "supervised") return "confirmed";
      if (s.defaultExecutionMode === "direct") return "direct";
    }
  } catch {
    // ignore
  }
  return "direct";
}

function onModeChange(e: Event) {
  const val = (e.target as HTMLSelectElement).value;
  const resolved: ExecutionMode =
    val === "user_default" ? resolveDefaultMode() : (val as ExecutionMode);
  sessionStore.updateExecutionMode(sessionId.value, resolved);
}

// ── Title editing ────────────────────────────────────────────────────────────
const editingTitle = ref(false);
const titleDraft = ref("");
const titleInputRef = ref<HTMLInputElement | null>(null);

function startEditTitle() {
  titleDraft.value = session.value?.name ?? "";
  editingTitle.value = true;
  nextTick(() => titleInputRef.value?.select());
}

function saveTitle() {
  const trimmed = titleDraft.value.trim();
  if (trimmed && trimmed !== session.value?.name) {
    sessionStore.renameSession(sessionId.value, trimmed);
  }
  editingTitle.value = false;
}

function cancelEditTitle() {
  editingTitle.value = false;
}

// ── FIFO message queue ───────────────────────────────────────────────────────
// Messages are always accepted. While James is responding we queue them and
// drain the queue as soon as streaming stops.
const sendQueue = ref<string[]>([]);
const hasSentFirstMessage = ref(false);
const streamingError = ref<string | null>(null);
let streamingTimeoutInterval: ReturnType<typeof setInterval> | null = null;
const streamingStartedAt = ref<number | null>(null);
const plannerStatus = ref("");

// Drain next queued message once streaming stops
watch(isStreaming, (nowStreaming) => {
  if (!nowStreaming && sendQueue.value.length > 0) {
    const next = sendQueue.value.shift()!;
    _doSend(next);
  }
});

function handleSend(text: string) {
  if (isStreaming.value) {
    // Optimistically show the queued message and enqueue for sending
    const queued: Message = {
      id: `queued-${Date.now()}`,
      sessionId: sessionId.value,
      role: "user",
      content: [{ type: "text", text: `[queued] ${text}` }],
      attachments: [],
      tokenCount: 0,
      createdAt: new Date().toISOString(),
    };
    messageStore.appendMessage(sessionId.value, queued);
    sendQueue.value.push(text);
    return;
  }
  _doSend(text);
}

async function _doSend(text: string) {
  if (!hasSentFirstMessage.value) {
    hasSentFirstMessage.value = true;
    sessionStore.autoNameSession(sessionId.value, text);
  }

  // Remove any stale [queued] optimistic message for this text
  const msgs = messageStore.getMessages(sessionId.value);
  const qIdx = msgs.findIndex(
    (m) =>
      m.id.startsWith("queued-") && m.content[0]?.text === `[queued] ${text}`,
  );
  if (qIdx !== -1) {
    msgs.splice(qIdx, 1);
    messageStore.setMessages(sessionId.value, [...msgs]);
  }

  // Optimistic real message
  const userMsg: Message = {
    id: `temp-${Date.now()}`,
    sessionId: sessionId.value,
    role: "user",
    content: [{ type: "text", text }],
    attachments: [],
    tokenCount: 0,
    createdAt: new Date().toISOString(),
  };
  messageStore.appendMessage(sessionId.value, userMsg);
  messageStore.startStreaming(sessionId.value);
  streamingStartedAt.value = Date.now();

  const response = await messageStore.sendMessage(sessionId.value, text);
  if (!response) {
    messageStore.stopStreaming();
    streamingStartedAt.value = null;
    messageStore.appendMessage(sessionId.value, {
      id: `error-${Date.now()}`,
      sessionId: sessionId.value,
      role: "assistant",
      content: [{ type: "text", text: "Failed to reach the server." }],
      attachments: [],
      tokenCount: 0,
      createdAt: new Date().toISOString(),
    });
  }
}

// ── Lifecycle ────────────────────────────────────────────────────────────────
onMounted(() => {
  sessionStore.setActive(sessionId.value);
  taskStore.fetchTasks(sessionId.value);

  // Streaming timeout: check every 5 s, stop after 45 s of no completion
  streamingTimeoutInterval = setInterval(() => {
    if (
      messageStore.streamingSessionId === sessionId.value &&
      streamingStartedAt.value !== null &&
      Date.now() - streamingStartedAt.value > 45_000
    ) {
      messageStore.stopStreaming();
      streamingError.value =
        "Streaming timed out. The server may be unresponsive.";
      streamingStartedAt.value = null;
    }
  }, 5_000);

  // Join session channel — the join reply carries the full message history
  const channel = socketStore.joinChannel(
    `session:${sessionId.value}`,
    {},
    (response) => {
      const rawMsgs = response.messages as
        | Array<Record<string, unknown>>
        | undefined;
      if (Array.isArray(rawMsgs) && rawMsgs.length > 0) {
        const normalized = rawMsgs.map((m) => ({
          id: m.id as string,
          sessionId: sessionId.value,
          role: m.role as Message["role"],
          content: m.content,
          attachments: [],
          tokenCount: 0,
          createdAt:
            (m.insertedAt as string) ||
            (m.inserted_at as string) ||
            new Date().toISOString(),
        })) as Message[];
        messageStore.setMessages(sessionId.value, normalized);
      } else if (!messageStore.getMessages(sessionId.value).length) {
        messageStore.setMessages(sessionId.value, []);
      }
    },
  );

  channel.on("message:new", (payload: unknown) => {
    const msg = payload as Message;
    if (
      msg.role === "assistant" &&
      messageStore.streamingSessionId === sessionId.value
    ) {
      messageStore.stopStreaming();
      streamingStartedAt.value = null;
    }
    if (msg.role === "user") {
      messageStore.replaceOrAppendMessage(sessionId.value, msg);
    } else {
      messageStore.appendMessage(sessionId.value, msg);
    }
  });

  channel.on("message:chunk", (payload: unknown) => {
    const { content } = payload as { content: string };
    if (messageStore.streamingSessionId !== sessionId.value) {
      messageStore.startStreaming(sessionId.value);
      streamingStartedAt.value = Date.now();
    }
    messageStore.appendStreamChunk(content);
  });

  channel.on("task:updated", (payload: unknown) => {
    taskStore.updateTask(payload as import("@/types/task").Task);
  });
  channel.on("artifact:created", () => {});

  // Planner channel
  const plannerChannel = socketStore.joinChannel(`planner:${sessionId.value}`);
  plannerChannel.on("planner:step", (payload: unknown) => {
    const step = (payload as { step: { type: string; description?: string } })
      .step;
    if (step.type === "decomposing") plannerStatus.value = "decomposing";
    else if (step.type === "dispatched") plannerStatus.value = "";
    else if (step.type === "awaiting_approval")
      plannerStatus.value = "awaiting approval";
    else if (step.type === "task_created") plannerStatus.value = "dispatching";
    else if (step.type === "error") plannerStatus.value = "";
  });
  plannerChannel.on("planner:tasks", (payload: unknown) => {
    const data = payload as { tasks: import("@/types/task").Task[] };
    data.tasks.forEach((t) => taskStore.updateTask(t));
  });
});

onUnmounted(() => {
  if (streamingTimeoutInterval !== null) {
    clearInterval(streamingTimeoutInterval);
    streamingTimeoutInterval = null;
  }
  socketStore.leaveChannel(`session:${sessionId.value}`);
  socketStore.leaveChannel(`planner:${sessionId.value}`);
  sessionStore.setActive(null);
  sendQueue.value = [];
});

function handleApprove(taskId: string) {
  taskStore.approveTask(taskId);
}

function handleReject(taskId: string) {
  taskStore.rejectTask(taskId);
}
</script>
