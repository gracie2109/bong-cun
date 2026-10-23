import { beforeEach, describe, expect, it, vi } from "vitest";
import { ref } from "vue";
import type { SavedItem } from "@bongcun/core/dashboard";

const save = { isPending: ref(false), mutateAsync: vi.fn() };
const reset = { isPending: ref(false), mutateAsync: vi.fn() };
vi.mock("@/features/admin/dashboard/layout/useLayoutMutations", () => ({ useLayoutMutations: () => ({ save, reset }) }));
vi.mock("@/i18n", () => ({ default: { global: { t: (key: string) => key } } }));
vi.mock("vue-sonner", () => ({ toast: { success: vi.fn(), error: vi.fn() } }));

const { useLayoutEditor } = await import("@/features/admin/dashboard/layout/useLayoutEditor");

const item = (id: string, over: Partial<SavedItem> = {}): SavedItem => ({ id: id.padEnd(8, "0"), type: "trend", x: 0, y: 0, w: 4, h: 4, ...over });

const setup = () => {
  const items = ref([item("a"), item("b", { y: 4 })]);
  const version = ref(3);
  const refetch = vi.fn().mockResolvedValue(undefined);
  const editor = useLayoutEditor(ref("business"), { items, version, refetch });
  return { editor, items, version, refetch };
};

describe("useLayoutEditor", () => {
  beforeEach(() => {
    save.mutateAsync.mockReset();
    reset.mutateAsync.mockReset();
  });

  it("edits a draft copy and is only dirty once it differs", () => {
    const { editor, items } = setup();
    editor.start();
    expect(editor.isDirty.value).toBe(false);
    editor.update([item("a", { w: 2 }), item("b", { y: 4 })]);
    expect(editor.isDirty.value).toBe(true);
    expect(items.value[0]?.w).toBe(4);
    editor.cancel();
    expect(editor.editing.value).toBe(false);
    expect(editor.items.value[0]?.w).toBe(4);
  });

  it("saves with the version it was based on and leaves edit mode", async () => {
    const { editor } = setup();
    editor.start();
    editor.update([item("a", { w: 2 }), item("b", { y: 4 })]);
    save.mutateAsync.mockResolvedValue(4);
    await editor.persist();
    expect(save.mutateAsync).toHaveBeenCalledWith(expect.objectContaining({ dashboardKey: "business", expectedVersion: 3 }));
    expect(editor.editing.value).toBe(false);
  });

  it("flags a conflict, keeps the draft, and overwrites on the fresh version", async () => {
    const { editor, version, refetch } = setup();
    editor.start();
    editor.update([item("a", { w: 2 }), item("b", { y: 4 })]);
    save.mutateAsync.mockRejectedValueOnce({ hint: "layout_conflict" });
    await editor.persist();
    expect(editor.conflict.value).toBe(true);
    expect(editor.editing.value).toBe(true);

    refetch.mockImplementation(async () => { version.value = 9; });
    save.mutateAsync.mockResolvedValueOnce(10);
    await editor.overwrite();
    expect(save.mutateAsync).toHaveBeenLastCalledWith(expect.objectContaining({ expectedVersion: 9 }));
    expect(editor.conflict.value).toBe(false);
    expect(editor.editing.value).toBe(false);
  });

  it("drops the draft when asked to load the new layout", async () => {
    const { editor, refetch } = setup();
    editor.start();
    editor.update([item("a", { w: 1 })]);
    save.mutateAsync.mockRejectedValueOnce({ hint: "layout_conflict" });
    await editor.persist();
    await editor.reload();
    expect(refetch).toHaveBeenCalled();
    expect(editor.editing.value).toBe(false);
    expect(editor.conflict.value).toBe(false);
  });

  it("ignores updates outside edit mode", () => {
    const { editor } = setup();
    editor.update([item("z")]);
    expect(editor.items.value).toHaveLength(2);
  });
});
