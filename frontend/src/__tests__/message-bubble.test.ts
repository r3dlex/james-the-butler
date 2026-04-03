// @vitest-environment happy-dom
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import MessageBubble from "../components/session/MessageBubble.vue";
import type { Message } from "../types/message";

function userMsg(text: string): Message {
  return {
    id: "1",
    sessionId: "s1",
    role: "user",
    content: [{ type: "text", text }],
    attachments: [],
    tokenCount: 0,
    createdAt: "",
  };
}

function assistantMsg(text: string): Message {
  return {
    id: "2",
    sessionId: "s1",
    role: "assistant",
    content: [{ type: "text", text }],
    attachments: [],
    tokenCount: 0,
    createdAt: "",
  };
}

describe("MessageBubble", () => {
  it("does not render a 'You' label for user messages", () => {
    const wrapper = mount(MessageBubble, {
      props: { message: userMsg("hello") },
    });
    expect(wrapper.text()).not.toContain("You");
  });

  it("does not render a 'James' label for assistant messages", () => {
    const wrapper = mount(MessageBubble, {
      props: { message: assistantMsg("hi there") },
    });
    expect(wrapper.text()).not.toContain("James");
  });

  it("user message container has a dark background class", () => {
    const wrapper = mount(MessageBubble, {
      props: { message: userMsg("hello") },
    });
    const hasDarkBg = wrapper
      .findAll("div")
      .some(
        (d) =>
          d.classes().some((c) => c.startsWith("bg-")) ||
          (d.attributes("style") ?? "").includes("background"),
      );
    expect(hasDarkBg).toBe(true);
  });

  it("assistant message renders markdown text content", () => {
    const wrapper = mount(MessageBubble, {
      props: { message: assistantMsg("**bold text**") },
    });
    expect(wrapper.html()).toContain("<strong>");
  });

  it("user message text is visible in rendered output", () => {
    const wrapper = mount(MessageBubble, {
      props: { message: userMsg("test input") },
    });
    expect(wrapper.text()).toContain("test input");
  });
});
