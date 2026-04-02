// @vitest-environment happy-dom
/**
 * Integration tests for the SessionView component.
 *
 * These are component-level integration tests — not browser E2E.
 * They exercise the full component tree (SessionView + child components)
 * against mocked API / Phoenix socket services, using real Pinia stores.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import type { Task } from "../../types/task";
import type { Message, ContentBlock } from "../../types/message";

// ---------------------------------------------------------------------------
// Service mocks
// ---------------------------------------------------------------------------

// Capture channel event handlers so we can simulate incoming events.
type EventHandler = (payload: unknown) => void;

interface MockChannel {
  join: ReturnType<typeof vi.fn>;
  on: ReturnType<typeof vi.fn>;
  leave: ReturnType<typeof vi.fn>;
  _handlers: Record<string, EventHandler>;
  _trigger: (event: string, payload: unknown) => void;
}

function makeMockChannel(): MockChannel {
  const handlers: Record<string, EventHandler> = {};

  const channel: MockChannel = {
    join: vi.fn(() => ({
      receive: vi.fn((_event: string, cb: (resp: unknown) => void) => {
        if (_event === "ok") {
          cb({ messages: [] });
        }
        return { receive: vi.fn() };
      }),
    })),
    on: vi.fn((event: string, handler: EventHandler) => {
      handlers[event] = handler;
    }),
    leave: vi.fn(),
    _handlers: handlers,
    _trigger(event: string, payload: unknown) {
      if (handlers[event]) {
        handlers[event](payload);
      }
    },
  };

  return channel;
}

// Channels keyed by topic — tests access them to simulate incoming events.
const mockChannels: Record<string, MockChannel> = {};

vi.mock("../../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn().mockResolvedValue({ session: { messageCount: 0 }, tasks: [] }),
    post: vi.fn().mockResolvedValue({
      message: {
        id: "server-msg-1",
        sessionId: "test-session-id",
        role: "user",
        content: [{ type: "text", text: "Hello" }],
        attachments: [],
        tokenCount: 0,
        createdAt: new Date().toISOString(),
      },
    }),
    delete: vi.fn(),
  },
}));

vi.mock("../../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(() => ({
    onOpen: vi.fn(),
    onClose: vi.fn(),
    onError: vi.fn(),
    channel: vi.fn((topic: string) => {
      if (!mockChannels[topic]) {
        mockChannels[topic] = makeMockChannel();
      }
      return mockChannels[topic];
    }),
  })),
}));

// ---------------------------------------------------------------------------
// Router mock — useRoute returns a fixed params.id
// ---------------------------------------------------------------------------

const SESSION_ID = "test-session-id";

vi.mock("vue-router", () => ({
  useRoute: vi.fn(() => ({
    params: { id: SESSION_ID },
  })),
  useRouter: vi.fn(() => ({
    push: vi.fn(),
  })),
}));

// ---------------------------------------------------------------------------
// Component stubs
// ---------------------------------------------------------------------------

// ChatInput emits "send" with the typed text when the Send button is clicked.
// We expose a `name` property so findComponent({ name }) works.
const ChatInputStub = {
  name: "ChatInput",
  template: `
    <div class="chat-input">
      <textarea
        class="message-textarea"
        @input="value = $event.target.value"
      />
      <button class="send-button" @click="$emit('send', value)">Send</button>
    </div>
  `,
  emits: ["send"],
  data() {
    return { value: "" };
  },
};

// SessionActivityPanel renders tasks and exposes plannerStatus as a data attribute.
const SessionActivityPanelStub = {
  name: "SessionActivityPanel",
  template: `
    <div
      class="session-activity-panel"
      :data-planner-status="plannerStatus"
    >
      <div
        v-for="task in tasks"
        :key="task.id"
        class="task-item"
        :data-task-id="task.id"
        :data-status="task.status"
      >{{ task.description }}</div>
    </div>
  `,
  props: ["tasks", "plannerStatus"],
  emits: ["approve", "reject"],
};

const ChatMessageStreamStub = {
  name: "ChatMessageStream",
  template: `
    <div class="chat-message-stream">
      <div
        v-for="msg in messages"
        :key="msg.id"
        class="message-bubble"
        :data-role="msg.role"
        :data-id="msg.id"
      >
        <span v-for="(block, i) in msg.content" :key="i">{{ block.text }}</span>
      </div>
      <div v-if="isStreaming" class="typing-indicator">Typing...</div>
      <div v-if="streamingText" class="streaming-text">{{ streamingText }}</div>
    </div>
  `,
  props: ["messages", "isStreaming", "streamingText"],
};

const stubs = {
  RouterLink: { template: "<a><slot /></a>" },
  SessionActivityPanel: SessionActivityPanelStub,
  ChatMessageStream: ChatMessageStreamStub,
  ChatInput: ChatInputStub,
};

// ---------------------------------------------------------------------------
// Helper: mount SessionView with a seeded session in the store
// ---------------------------------------------------------------------------

async function mountSessionView() {
  const pinia = createPinia();
  setActivePinia(pinia);

  const { useSessionStore } = await import("../../stores/sessions");
  const sessionStore = useSessionStore();

  sessionStore.sessions.push({
    id: SESSION_ID,
    name: "Test Session",
    nameSetByUser: false,
    agentType: "chat",
    hostId: "host-1",
    projectId: null,
    status: "active",
    executionMode: "direct",
    personalityId: null,
    workingDirectories: [],
    mcpServers: [],
    keepIntermediates: false,
    tokenCount: 0,
    tokenCost: 0,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });

  const { default: SessionView } = await import("../../pages/SessionView.vue");

  const wrapper = mount(SessionView, {
    global: {
      plugins: [pinia],
      stubs,
    },
  });

  await flushPromises();

  return { wrapper, pinia };
}

// ---------------------------------------------------------------------------
// Helper: simulate a message send by clicking the Send button in the stub
// ---------------------------------------------------------------------------

async function triggerSend(wrapper: ReturnType<typeof mount>, text: string) {
  const textarea = wrapper.find(".message-textarea");
  await textarea.setValue(text);
  const btn = wrapper.find(".send-button");
  await btn.trigger("click");
  await flushPromises();
}

// ---------------------------------------------------------------------------
// Tests — mount and message send
// ---------------------------------------------------------------------------

describe("SessionView — session view mount and message send", () => {
  beforeEach(() => {
    for (const key of Object.keys(mockChannels)) {
      delete mockChannels[key];
    }
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("mounts without errors and renders the session name", async () => {
    const { wrapper } = await mountSessionView();
    expect(wrapper.exists()).toBe(true);
    expect(wrapper.text()).toContain("Test Session");
  });

  it("optimistic user message appears immediately after send", async () => {
    const { wrapper, pinia } = await mountSessionView();

    const { useMessageStore } = await import("../../stores/messages");
    const messageStore = useMessageStore(pinia);

    await triggerSend(wrapper, "Hello there!");

    const messages = messageStore.getMessages(SESSION_ID);
    const userMsg = messages.find(
      (m: Message) =>
        m.role === "user" &&
        m.content.some((b: ContentBlock) => b.text === "Hello there!"),
    );

    expect(userMsg).toBeDefined();
  });

  it("streaming indicator appears when send is in progress", async () => {
    const { wrapper } = await mountSessionView();

    // Keep the post pending so streaming state lingers.
    const { api } = await import("../../services/api");
    vi.mocked(api.post).mockImplementationOnce(
      () => new Promise(() => {}), // never resolves
    );

    await triggerSend(wrapper, "streaming test");

    expect(wrapper.find(".typing-indicator").exists()).toBe(true);
  });

  it("error fallback message appears when API call fails", async () => {
    const { wrapper, pinia } = await mountSessionView();

    const { api } = await import("../../services/api");
    vi.mocked(api.post).mockRejectedValueOnce(new Error("Network error"));

    const { useMessageStore } = await import("../../stores/messages");
    const messageStore = useMessageStore(pinia);

    await triggerSend(wrapper, "trigger failure");

    const messages = messageStore.getMessages(SESSION_ID);
    const errMsg = messages.find(
      (m: Message) =>
        m.role === "assistant" &&
        m.content.some((b: ContentBlock) =>
          b.text?.includes("Failed to reach the server"),
        ),
    );

    expect(errMsg).toBeDefined();
  });
});

// ---------------------------------------------------------------------------
// Tests — channel event simulation
// ---------------------------------------------------------------------------

describe("SessionView — channel event simulation", () => {
  beforeEach(() => {
    for (const key of Object.keys(mockChannels)) {
      delete mockChannels[key];
    }
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("incoming message:chunk shows typing indicator and accumulates streaming text", async () => {
    const { wrapper, pinia } = await mountSessionView();

    const { useMessageStore } = await import("../../stores/messages");
    const messageStore = useMessageStore(pinia);

    const sessionChannel = mockChannels[`session:${SESSION_ID}`];
    expect(sessionChannel).toBeDefined();

    sessionChannel._trigger("message:chunk", { content: "Hello " });
    sessionChannel._trigger("message:chunk", { content: "world!" });
    await flushPromises();

    expect(messageStore.streamingSessionId).toBe(SESSION_ID);
    expect(messageStore.streamingContent).toBe("Hello world!");
    expect(wrapper.find(".typing-indicator").exists()).toBe(true);
  });

  it("incoming message:new from assistant stops streaming and adds message", async () => {
    const { wrapper, pinia } = await mountSessionView();

    const { useMessageStore } = await import("../../stores/messages");
    const messageStore = useMessageStore(pinia);

    const sessionChannel = mockChannels[`session:${SESSION_ID}`];

    // Start streaming
    sessionChannel._trigger("message:chunk", { content: "Partial..." });
    await flushPromises();

    expect(messageStore.streamingSessionId).toBe(SESSION_ID);

    // Complete message arrives
    const assistantMsg: Message = {
      id: "agent-msg-1",
      sessionId: SESSION_ID,
      role: "assistant",
      content: [{ type: "text", text: "Hello! How can I help?" }],
      attachments: [],
      tokenCount: 15,
      createdAt: new Date().toISOString(),
    };

    sessionChannel._trigger("message:new", assistantMsg);
    await flushPromises();

    expect(messageStore.streamingSessionId).toBeNull();

    const messages = messageStore.getMessages(SESSION_ID);
    const agentMsg = messages.find((m: Message) => m.id === "agent-msg-1");
    expect(agentMsg).toBeDefined();
    expect(wrapper.find(".typing-indicator").exists()).toBe(false);
  });

  it("incoming message:new (user role) does not stop streaming", async () => {
    const { pinia } = await mountSessionView();

    const { useMessageStore } = await import("../../stores/messages");
    const messageStore = useMessageStore(pinia);

    const sessionChannel = mockChannels[`session:${SESSION_ID}`];

    messageStore.startStreaming(SESSION_ID);

    const userMsg: Message = {
      id: "user-echo-1",
      sessionId: SESSION_ID,
      role: "user",
      content: [{ type: "text", text: "echoed user msg" }],
      attachments: [],
      tokenCount: 0,
      createdAt: new Date().toISOString(),
    };

    sessionChannel._trigger("message:new", userMsg);
    await flushPromises();

    // Streaming should remain active — user messages don't stop it.
    expect(messageStore.streamingSessionId).toBe(SESSION_ID);
  });
});

// ---------------------------------------------------------------------------
// Tests — task list updates via planner channel
// ---------------------------------------------------------------------------

describe("SessionView — task list updates via planner channel", () => {
  beforeEach(() => {
    for (const key of Object.keys(mockChannels)) {
      delete mockChannels[key];
    }
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it("task:updated channel event updates task status in the store", async () => {
    const { pinia } = await mountSessionView();

    const { useTaskStore } = await import("../../stores/tasks");
    const taskStore = useTaskStore(pinia);

    const existingTask: Task = {
      id: "task-1",
      sessionId: SESSION_ID,
      description: "Generate response",
      riskLevel: "read_only",
      status: "pending",
      hostId: "host-1",
      agentId: null,
      createdAt: new Date().toISOString(),
      startedAt: null,
      completedAt: null,
    };
    taskStore.updateTask(existingTask);

    const sessionChannel = mockChannels[`session:${SESSION_ID}`];
    const updatedTask: Task = { ...existingTask, status: "completed" };
    sessionChannel._trigger("task:updated", updatedTask);
    await flushPromises();

    const stored = taskStore.tasks.find((t) => t.id === "task-1");
    expect(stored?.status).toBe("completed");
  });

  it("planner:step event with task_created type sets plannerStatus to 'dispatching'", async () => {
    const { wrapper } = await mountSessionView();

    const plannerChannel = mockChannels[`planner:${SESSION_ID}`];
    expect(plannerChannel).toBeDefined();

    plannerChannel._trigger("planner:step", {
      step: { type: "task_created", description: "Task dispatched" },
    });
    await flushPromises();

    const panel = wrapper.find(".session-activity-panel");
    expect(panel.attributes("data-planner-status")).toBe("dispatching");
  });

  it("planner:step event with awaiting_approval sets plannerStatus to 'awaiting approval'", async () => {
    const { wrapper } = await mountSessionView();

    const plannerChannel = mockChannels[`planner:${SESSION_ID}`];

    plannerChannel._trigger("planner:step", {
      step: { type: "awaiting_approval", description: "Needs approval" },
    });
    await flushPromises();

    const panel = wrapper.find(".session-activity-panel");
    expect(panel.attributes("data-planner-status")).toBe("awaiting approval");
  });

  it("planner:tasks channel event upserts tasks into the task store", async () => {
    const { pinia } = await mountSessionView();

    const { useTaskStore } = await import("../../stores/tasks");
    const taskStore = useTaskStore(pinia);

    const plannerChannel = mockChannels[`planner:${SESSION_ID}`];

    const newTask: Task = {
      id: "task-planner-1",
      sessionId: SESSION_ID,
      description: "Research task from planner",
      riskLevel: "read_only",
      status: "pending",
      hostId: "host-1",
      agentId: null,
      createdAt: new Date().toISOString(),
      startedAt: null,
      completedAt: null,
    };

    plannerChannel._trigger("planner:tasks", { tasks: [newTask] });
    await flushPromises();

    const stored = taskStore.tasks.find((t) => t.id === "task-planner-1");
    expect(stored).toBeDefined();
    expect(stored?.description).toBe("Research task from planner");
  });

  it("activity panel renders tasks that are updated via channel events", async () => {
    const { wrapper, pinia } = await mountSessionView();

    const { useTaskStore } = await import("../../stores/tasks");
    const taskStore = useTaskStore(pinia);

    const task: Task = {
      id: "task-ui-1",
      sessionId: SESSION_ID,
      description: "Visible task in panel",
      riskLevel: "additive",
      status: "running",
      hostId: "host-1",
      agentId: null,
      createdAt: new Date().toISOString(),
      startedAt: null,
      completedAt: null,
    };

    taskStore.updateTask(task);
    await flushPromises();

    const taskItems = wrapper.findAll(".task-item");
    const hasTask = taskItems.some((el) =>
      el.text().includes("Visible task in panel"),
    );
    expect(hasTask).toBe(true);
  });
});
