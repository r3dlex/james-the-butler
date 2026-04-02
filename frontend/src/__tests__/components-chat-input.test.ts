// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";

// ── Service mocks ─────────────────────────────────────────────────────────────
vi.mock("../services/api", () => ({
  api: {
    setToken: vi.fn(),
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

vi.mock("../services/phoenix", () => ({
  connectSocket: vi.fn(),
  disconnectSocket: vi.fn(),
  getSocket: vi.fn(() => ({
    channel: vi.fn(() => ({
      join: vi.fn(() => ({ receive: vi.fn().mockReturnThis() })),
      on: vi.fn(),
      leave: vi.fn(),
    })),
    onOpen: vi.fn(),
    onClose: vi.fn(),
    onError: vi.fn(),
    isConnected: vi.fn(() => false),
    connect: vi.fn(),
    disconnect: vi.fn(),
  })),
}));

// Router stub — ChatInput uses RouterLink internally for the model picker link
vi.mock("vue-router", async (importOriginal) => {
  const actual = await importOriginal<typeof import("vue-router")>();
  return {
    ...actual,
    useRouter: vi.fn(() => ({ push: vi.fn() })),
    useRoute: vi.fn(() => ({ params: { id: "sess-1" }, path: "/" })),
    RouterLink: { template: "<a><slot /></a>" },
  };
});

describe("ChatInput", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  async function mountChatInput(props: Record<string, unknown> = {}) {
    const { default: ChatInput } =
      await import("../components/session/ChatInput.vue");
    return mount(ChatInput, {
      props,
      attachTo: document.body,
    });
  }

  // ── 1. Send button disabled when text is empty ──────────────────────────────
  it("send button is disabled when text is empty", async () => {
    const wrapper = await mountChatInput();
    // The send button is the last button in the toolbar
    const buttons = wrapper.findAll("button");
    const sendButton = buttons[buttons.length - 1];
    expect(sendButton.attributes("disabled")).toBeDefined();
    wrapper.unmount();
  });

  // ── 2. Send button enabled when text is non-empty ──────────────────────────
  it("send button is enabled when text is non-empty", async () => {
    const wrapper = await mountChatInput();
    const textarea = wrapper.find("textarea");
    await textarea.setValue("hello");
    await textarea.trigger("input");
    const buttons = wrapper.findAll("button");
    const sendButton = buttons[buttons.length - 1];
    expect(sendButton.attributes("disabled")).toBeUndefined();
    wrapper.unmount();
  });

  // ── 3. Send button disabled while disabled prop is true ────────────────────
  it("send button is disabled while disabled prop is true", async () => {
    const wrapper = await mountChatInput({ disabled: true });
    const textarea = wrapper.find("textarea");
    await textarea.setValue("some text");
    await textarea.trigger("input");
    const buttons = wrapper.findAll("button");
    const sendButton = buttons[buttons.length - 1];
    expect(sendButton.attributes("disabled")).toBeDefined();
    wrapper.unmount();
  });

  // ── 4. Emits send event with trimmed text on button click ──────────────────
  it("emits send event with trimmed text on button click", async () => {
    const wrapper = await mountChatInput();
    const textarea = wrapper.find("textarea");
    await textarea.setValue(" hello ");
    await textarea.trigger("input");
    const buttons = wrapper.findAll("button");
    const sendButton = buttons[buttons.length - 1];
    await sendButton.trigger("click");
    expect(wrapper.emitted("send")).toBeTruthy();
    expect(wrapper.emitted("send")![0]).toEqual(["hello"]);
    wrapper.unmount();
  });

  // ── 5. Does not emit when text is whitespace only ──────────────────────────
  it("does not emit when text is whitespace only", async () => {
    const wrapper = await mountChatInput();
    const textarea = wrapper.find("textarea");
    await textarea.setValue("   ");
    await textarea.trigger("input");
    const buttons = wrapper.findAll("button");
    const sendButton = buttons[buttons.length - 1];
    await sendButton.trigger("click");
    expect(wrapper.emitted("send")).toBeFalsy();
    wrapper.unmount();
  });

  // ── 6. Pressing Enter submits the form ────────────────────────────────────
  it("pressing Enter submits the form", async () => {
    const wrapper = await mountChatInput();
    const textarea = wrapper.find("textarea");
    await textarea.setValue("hello from enter");
    await textarea.trigger("input");
    await textarea.trigger("keydown.enter");
    await flushPromises();
    expect(wrapper.emitted("send")).toBeTruthy();
    expect(wrapper.emitted("send")![0]).toEqual(["hello from enter"]);
    wrapper.unmount();
  });

  // ── 7. Textarea height is capped at 50vh when scrollHeight exceeds the cap ──
  it("textarea height is capped at 50vh when scrollHeight exceeds the cap", async () => {
    // happy-dom defaults: innerHeight is 768, so 50vh = 384px
    const cap = Math.floor(window.innerHeight * 0.5);
    const wrapper = await mountChatInput();
    const textarea = wrapper.find("textarea").element as HTMLTextAreaElement;

    Object.defineProperty(textarea, "scrollHeight", {
      configurable: true,
      get: () => cap + 200, // well over the cap
    });

    await wrapper.find("textarea").trigger("input");

    expect(textarea.style.height).toBe(`${cap}px`);
    expect(textarea.style.overflowY).toBe("auto");
    wrapper.unmount();
  });

  // ── 8. Textarea overflow-y is hidden when content is below the cap ─────────
  it("textarea overflow-y is hidden when content is below cap", async () => {
    const wrapper = await mountChatInput();
    const textarea = wrapper.find("textarea").element as HTMLTextAreaElement;

    Object.defineProperty(textarea, "scrollHeight", {
      configurable: true,
      get: () => 80,
    });

    await wrapper.find("textarea").trigger("input");

    expect(textarea.style.overflowY).toBe("hidden");
    wrapper.unmount();
  });

  // ── 9. Textarea height reflects scrollHeight when below cap ───────────────
  it("textarea height equals scrollHeight when content is within cap", async () => {
    const wrapper = await mountChatInput();
    const textarea = wrapper.find("textarea").element as HTMLTextAreaElement;

    Object.defineProperty(textarea, "scrollHeight", {
      configurable: true,
      get: () => 120,
    });

    await wrapper.find("textarea").trigger("input");

    expect(textarea.style.height).toBe("120px");
    wrapper.unmount();
  });
});
