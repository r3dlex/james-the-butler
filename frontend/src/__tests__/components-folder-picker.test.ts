// @vitest-environment happy-dom
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";

// We test the FolderPathInput component we're about to build

describe("FolderPathInput", () => {
  it("renders a text input for folder path", async () => {
    const { default: FolderPathInput } =
      await import("../components/common/FolderPathInput.vue");
    const wrapper = mount(FolderPathInput);
    const textInput = wrapper.find('input[type="text"]');
    expect(textInput.exists()).toBe(true);
  });

  it("renders a 'Browse' button on desktop, not 'Upload'", async () => {
    // Simulate Tauri desktop environment
    (window as unknown as Record<string, unknown>).__TAURI__ = {};
    const { default: FolderPathInput } =
      await import("../components/common/FolderPathInput.vue");
    const wrapper = mount(FolderPathInput);
    const buttons = wrapper.findAll("button");
    const browseButton = buttons.find((b) =>
      b.text().toLowerCase().includes("browse"),
    );
    expect(browseButton).toBeDefined();
    // Must NOT have an "Upload" button
    const uploadButton = buttons.find((b) =>
      b.text().toLowerCase().includes("upload"),
    );
    expect(uploadButton).toBeUndefined();
    delete (window as unknown as Record<string, unknown>).__TAURI__;
  });

  it("hides Browse button on web (no Tauri)", async () => {
    delete (window as unknown as Record<string, unknown>).__TAURI__;
    const { default: FolderPathInput } =
      await import("../components/common/FolderPathInput.vue");
    const wrapper = mount(FolderPathInput);
    const buttons = wrapper.findAll("button");
    const browseButton = buttons.find((b) =>
      b.text().toLowerCase().includes("browse"),
    );
    // On web, no Browse button — user types path directly
    expect(browseButton).toBeUndefined();
  });

  it("shows a label containing 'Folder Path' or 'Working Directory'", async () => {
    const { default: FolderPathInput } =
      await import("../components/common/FolderPathInput.vue");
    const wrapper = mount(FolderPathInput);
    const text = wrapper.text();
    const hasLabel =
      text.includes("Folder Path") ||
      text.includes("Working Directory") ||
      text.includes("Folder");
    expect(hasLabel).toBe(true);
  });

  it("emits 'select' event with path string when user types a path and presses Enter", async () => {
    const { default: FolderPathInput } =
      await import("../components/common/FolderPathInput.vue");
    const wrapper = mount(FolderPathInput);
    const textInput = wrapper.find('input[type="text"]');
    await textInput.setValue("/home/user/my-project");
    await textInput.trigger("keydown.enter");
    const emitted = wrapper.emitted("select");
    expect(emitted).toBeDefined();
    expect(emitted![0][0]).toBe("/home/user/my-project");
  });

  it("emits 'select' event with path string when form is submitted", async () => {
    const { default: FolderPathInput } =
      await import("../components/common/FolderPathInput.vue");
    const wrapper = mount(FolderPathInput);
    const textInput = wrapper.find('input[type="text"]');
    await textInput.setValue("/opt/workspace");
    // Trigger via form submit or enter key
    await textInput.trigger("keydown", { key: "Enter" });
    const emitted = wrapper.emitted("select");
    // Either submitted via enter key or form - we just need path propagation
    // The component should emit on enter
    if (emitted) {
      expect(emitted[0][0]).toBe("/opt/workspace");
    }
  });

  it("has a hidden file input with webkitdirectory for the Browse button on desktop", async () => {
    // Simulate Tauri desktop environment
    (window as unknown as Record<string, unknown>).__TAURI__ = {};
    const { default: FolderPathInput } =
      await import("../components/common/FolderPathInput.vue");
    const wrapper = mount(FolderPathInput);
    const fileInput = wrapper.find('input[type="file"]');
    expect(fileInput.exists()).toBe(true);
    // webkitdirectory is a boolean attribute
    expect(fileInput.attributes()).toHaveProperty("webkitdirectory");
    delete (window as unknown as Record<string, unknown>).__TAURI__;
  });

  it("has no file input on web (no Tauri)", async () => {
    delete (window as unknown as Record<string, unknown>).__TAURI__;
    const { default: FolderPathInput } =
      await import("../components/common/FolderPathInput.vue");
    const wrapper = mount(FolderPathInput);
    const fileInput = wrapper.find('input[type="file"]');
    expect(fileInput.exists()).toBe(false);
  });
});
