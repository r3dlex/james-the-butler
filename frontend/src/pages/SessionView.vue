<template>
  <div class="flex h-full">
    <!-- Main chat area (no left panel) -->
    <div class="flex flex-1 flex-col">
      <!-- Session header: title + host + paths + token cost -->
      <div
        class="flex items-center gap-3 border-b px-4 py-2"
        style="border-color: var(--color-border)"
      >
        <!-- Editable title -->
        <div class="min-w-0 shrink">
          <input
            v-if="editingTitle"
            ref="titleInputRef"
            v-model="titleDraft"
            class="max-w-48 rounded border bg-transparent px-2 py-0.5 text-sm font-medium outline-none focus:border-[var(--color-gold)]"
            style="
              border-color: var(--color-border);
              color: var(--color-text);
            "
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

        <!-- Working paths -->
        <div
          v-if="session?.workingDirectories?.length"
          class="flex items-center gap-1 rounded-md px-2 py-1"
          style="background: var(--color-surface)"
          :title="session.workingDirectories.join('\n')"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            style="color: var(--color-text-dim)"
          >
            <path
              d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"
            />
          </svg>
          <span class="max-w-32 truncate text-xs" style="color: var(--color-text-dim)">
            {{ session.workingDirectories[0] }}
          </span>
          <span
            v-if="session.workingDirectories.length > 1"
            class="text-xs"
            style="color: var(--color-text-dim)"
          >
            +{{ session.workingDirectories.length - 1 }}
          </span>
        </div>

        <!-- Token cost -->
        <div
          class="flex items-center gap-1 rounded-md px-2 py-1"
          style="background: var(--color-surface)"
        >
          <span
            class="flex h-4 w-4 items-center justify-center rounded-full text-xs font-bold"
            style="
              background: var(--color-gold);
              color: var(--color-navy-deep);
            "
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
      </div>

      <ChatMessageStream :messages="messages" :is-streaming="isStreaming" />
      <ChatInput :disabled="isStreaming" @send="handleSend" />
    </div>

    <!-- Right: task panel (kept as-is) -->
    <SessionActivityPanel :tasks="tasks" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from "vue";
import { useRoute } from "vue-router";
import { useSessionStore } from "@/stores/sessions";
import { useMessageStore } from "@/stores/messages";
import { useTaskStore } from "@/stores/tasks";
import { useSocketStore } from "@/stores/socket";
import { useTokenStore } from "@/stores/tokens";
import type { Message, ContentBlock } from "@/types/message";
import SessionActivityPanel from "@/components/session/SessionActivityPanel.vue";
import ChatMessageStream from "@/components/session/ChatMessageStream.vue";
import ChatInput from "@/components/session/ChatInput.vue";

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
const tasks = computed(() => taskStore.getTasksForSession(sessionId.value));

const sessionCost = computed(() => {
  const usage = tokenStore.getUsage(sessionId.value);
  return usage ? `$${usage.cost.toFixed(4)}` : "$0.00";
});

// Title editing
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

const hasSentFirstMessage = ref(false);

onMounted(() => {
  sessionStore.setActive(sessionId.value);
  messageStore.fetchMessages(sessionId.value);
  taskStore.fetchTasks(sessionId.value);

  const channel = socketStore.joinChannel(`session:${sessionId.value}`);
  channel.on("new_message", (payload: unknown) => {
    messageStore.appendMessage(sessionId.value, payload as Message);
  });
  channel.on("streaming_start", () => {
    messageStore.setStreamingState(sessionId.value);
  });
  channel.on("streaming_stop", () => {
    messageStore.setStreamingState(null);
  });
  channel.on("task_update", (payload: unknown) => {
    taskStore.updateTask(payload as import("@/types/task").Task);
  });
});

onUnmounted(() => {
  socketStore.leaveChannel(`session:${sessionId.value}`);
  sessionStore.setActive(null);
});

async function handleSend(text: string) {
  if (!hasSentFirstMessage.value) {
    hasSentFirstMessage.value = true;
    sessionStore.autoNameSession(sessionId.value, text);
  }

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
  messageStore.setStreamingState(sessionId.value);

  const response = await messageStore.sendMessage(sessionId.value, text);
  if (!response) {
    try {
      const res = await fetch("http://localhost:4000/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          messages: messages.value
            .filter((m) => m.role !== "system")
            .map((m) => ({
              role: m.role,
              content: m.content
                .filter((b) => b.type === "text")
                .map((b) => b.text)
                .join("\n"),
            })),
        }),
      });
      const data = await res.json();
      const textBlock = data.content?.find(
        (b: ContentBlock) => b.type === "text",
      );
      const cost = ((data.usage?.input_tokens ?? 0) + (data.usage?.output_tokens ?? 0)) * 0.000003;
      tokenStore.updateUsage(sessionId.value, {
        sessionId: sessionId.value,
        inputTokens: data.usage?.input_tokens ?? 0,
        outputTokens: data.usage?.output_tokens ?? 0,
        cost,
      });
      const assistantMsg: Message = {
        id: `temp-${Date.now()}`,
        sessionId: sessionId.value,
        role: "assistant",
        content: [
          { type: "text", text: textBlock?.text ?? JSON.stringify(data) },
        ],
        attachments: [],
        tokenCount: data.usage?.output_tokens ?? 0,
        createdAt: new Date().toISOString(),
      };
      messageStore.appendMessage(sessionId.value, assistantMsg);
    } catch {
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
  messageStore.setStreamingState(null);
}
</script>
