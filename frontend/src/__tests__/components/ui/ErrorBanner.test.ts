// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { defineComponent, h } from "vue";

// ── PrimeVue Message stub that renders the default slot ───────────────────────
vi.mock("primevue/message", () => ({
  default: defineComponent({
    name: "Message",
    props: ["severity", "closable"],
    emits: ["close"],
    setup(props, { emit, slots }) {
      return () =>
        h(
          "div",
          { "data-testid": "message", "data-closable": String(props.closable) },
          [
            h("button", { onClick: () => emit("close") }, "Close"),
            slots.default?.(),
          ],
        );
    },
  }),
}));

describe("ErrorBanner — rendering", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders the message text", async () => {
    const { default: ErrorBanner } =
      await import("@/components/ui/ErrorBanner.vue");
    const wrapper = mount(ErrorBanner, {
      props: { message: "Something went wrong" },
    });
    // The stub renders slot content alongside the close button
    expect(wrapper.text()).toContain("Something went wrong");
  });

  it("renders empty content when message is null", async () => {
    const { default: ErrorBanner } =
      await import("@/components/ui/ErrorBanner.vue");
    const wrapper = mount(ErrorBanner, {
      props: { message: null },
    });
    // Message component always renders; slot content is empty with null message
    expect(wrapper.find("[data-testid='message']").exists()).toBe(true);
    expect(wrapper.text()).toBe("Close");
  });
});

describe("ErrorBanner — dismiss emit", () => {
  beforeEach(() => vi.clearAllMocks());

  it('emits "dismiss" when close button is clicked', async () => {
    const { default: ErrorBanner } =
      await import("@/components/ui/ErrorBanner.vue");
    const wrapper = mount(ErrorBanner, {
      props: { message: "Error!", dismissible: true },
    });

    const closeBtn = wrapper
      .findAll("button")
      .find((b) => b.text() === "Close");
    await closeBtn!.trigger("click");

    expect(wrapper.emitted("dismiss")).toBeTruthy();
    expect(wrapper.emitted("dismiss")).toHaveLength(1);
  });
});

describe("ErrorBanner — dismissible prop", () => {
  beforeEach(() => vi.clearAllMocks());

  it("Message receives closable=true when dismissible=true", async () => {
    const { default: ErrorBanner } =
      await import("@/components/ui/ErrorBanner.vue");
    const wrapper = mount(ErrorBanner, {
      props: { message: "Alert", dismissible: true },
    });
    expect(
      wrapper.find("[data-testid='message']").attributes("data-closable"),
    ).toBe("true");
  });

  it("Message receives closable=false when dismissible=false", async () => {
    const { default: ErrorBanner } =
      await import("@/components/ui/ErrorBanner.vue");
    const wrapper = mount(ErrorBanner, {
      props: { message: "Alert", dismissible: false },
    });
    expect(
      wrapper.find("[data-testid='message']").attributes("data-closable"),
    ).toBe("false");
  });
});
