import type { Ref } from "vue";
import type { SavedItem } from "@bongcun/core/dashboard";
import { metaOf } from "../widgetTypes/meta";
import { moveBy, resizeTo } from "./layoutMath";

export type SizePreset = "small" | "medium" | "large";

/** The edit-menu actions on one item (no dragging needed), applied to the draft layout. */
export const useItemActions = (items: Ref<SavedItem[]>, update: (next: SavedItem[]) => void) => {
  const find = (id: string) => items.value.find((item) => item.id === id);

  const move = (id: string, step: -1 | 1) => update(moveBy(items.value, id, step));

  const resize = (id: string, preset: SizePreset) => {
    const item = find(id);
    const meta = item ? metaOf(item.type) : null;
    if (!item || !meta) return;
    const size = { small: meta.minSize, medium: meta.defaultSize, large: meta.maxSize }[preset];
    update(resizeTo(items.value, id, size, meta));
  };

  const remove = (id: string) => update(items.value.filter((item) => item.id !== id));

  return { move, resize, remove };
};
