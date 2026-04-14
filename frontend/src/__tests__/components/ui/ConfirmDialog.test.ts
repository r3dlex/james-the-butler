// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { flushPromises } from "@vue/test-utils";
import { defineComponent, h, watch } from "vue";

// ── PrimeVue Dialog stub ───────────────────────────────────────────────────────
// Mirrors primevue's Dialog behaviour:
// - Only renders when visible=true (like the real component)
// - Emits 'hide' when visible becomes false (like the real component)
vi.mock("primevue/dialog", () => ({
  default: defineComponent({
    props: ["visible", "header", "modal", "closable"],
    emits: ["hide", "update:visible"],
    setup(props, { emit, slots }) {
      let wasVisible = props.visible;
      // Watch for the dialog being closed externally (visible -> false)
      // and emit hide so ConfirmDialog's @hide="$emit('cancel')" fires.
      watch(
        () => props.visible,
        (next) => {
          if (wasVisible && !next) {
            emit("hide");
          }
          wasVisible = next;
        },
      );
      return () =>
        !props.visible
          ? null
          : h("div", { "data-testid": "dialog" }, [
              h("h2", {}, props.header ?? ""),
              slots.default?.(),
              h("div", { "data-testid": "dialog-footer" }, slots.footer?.()),
              h("button", { onClick: () => emit("hide") }, "Close"),
            ]);
    },
  }),
}));

describe("ConfirmDialog — props", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders with default labels when props are not provided", async () => {
    const { default: ConfirmDialog } =
      await import("@/components/ui/ConfirmDialog.vue");
    const wrapper = mount(ConfirmDialog, {
      props: { open: true, title: "Are you sure?" },
    });
    // The Dialog stub renders its footer via the footer slot
    expect(wrapper.find("[data-testid='dialog-footer']").text()).toContain(
      "Confirm",
    );
    expect(wrapper.find("[data-testid='dialog-footer']").text()).toContain(
      "Cancel",
    );
  });

  it("renders with custom labels when provided", async () => {
    const { default: ConfirmDialog } =
      await import("@/components/ui/ConfirmDialog.vue");
    const wrapper = mount(ConfirmDialog, {
      props: {
        open: true,
        title: "Delete?",
        confirmLabel: "Delete it",
        cancelLabel: "Keep it",
      },
    });
    expect(wrapper.find("[data-testid='dialog-footer']").text()).toContain(
      "Delete it",
    );
    expect(wrapper.find("[data-testid='dialog-footer']").text()).toContain(
      "Keep it",
    );
  });
});

describe("ConfirmDialog — emits", () => {
  beforeEach(() => vi.clearAllMocks());

  it('emits "confirm" when confirm button is clicked', async () => {
    const { default: ConfirmDialog } =
      await import("@/components/ui/ConfirmDialog.vue");
    const wrapper = mount(ConfirmDialog, {
      props: { open: true, title: "Confirm?", confirmLabel: "Go" },
    });

    const confirmBtn = wrapper.findAll("button").find((b) => b.text() === "Go");
    await confirmBtn!.trigger("click");

    expect(wrapper.emitted("confirm")).toBeTruthy();
    expect(wrapper.emitted("confirm")).toHaveLength(1);
  });

  it('emits "cancel" when cancel button is clicked', async () => {
    const { default: ConfirmDialog } =
      await import("@/components/ui/ConfirmDialog.vue");
    const wrapper = mount(ConfirmDialog, {
      props: { open: true, title: "Confirm?", cancelLabel: "Abort" },
    });

    const cancelBtn = wrapper
      .findAll("button")
      .find((b) => b.text() === "Abort");
    await cancelBtn!.trigger("click");

    expect(wrapper.emitted("cancel")).toBeTruthy();
    expect(wrapper.emitted("cancel")).toHaveLength(1);
  });

  it('emits "cancel" when dialog emits hide event', async () => {
    const { default: ConfirmDialog } =
      await import("@/components/ui/ConfirmDialog.vue");
    const wrapper = mount(ConfirmDialog, {
      props: { open: true, title: "Confirm?" },
    });

    // ConfirmDialog's Dialog @hide="$emit('cancel')" forwards Dialog's hide.
    // The Dialog stub emits 'hide' when its 'visible' prop goes false.
    // setProps triggers the stub's watch asynchronously, so flush promises first.
    await wrapper.setProps({ open: false });
    await flushPromises();

    expect(wrapper.emitted("cancel")).toBeTruthy();
  });
});

describe("ConfirmDialog — visible prop", () => {
  beforeEach(() => vi.clearAllMocks());

  it("dialog is present when open=true", async () => {
    const { default: ConfirmDialog } =
      await import("@/components/ui/ConfirmDialog.vue");
    const wrapper = mount(ConfirmDialog, {
      props: { open: true, title: "Visible" },
    });
    expect(wrapper.find("[data-testid='dialog']").exists()).toBe(true);
  });

  it("dialog is absent when open=false", async () => {
    const { default: ConfirmDialog } =
      await import("@/components/ui/ConfirmDialog.vue");
    const wrapper = mount(ConfirmDialog, {
      props: { open: false, title: "Hidden" },
    });
    expect(wrapper.find("[data-testid='dialog']").exists()).toBe(false);
  });
});
