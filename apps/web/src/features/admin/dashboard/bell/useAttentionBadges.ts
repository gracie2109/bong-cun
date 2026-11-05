import { computed } from "vue";
import { attentionBadges } from "./attentionBadges";
import { useBellItems } from "./useBellItems";

/** Sidebar badges for vaccines due and lots expiring at the working branch (same cached sources as the bell). */
export const useAttentionBadges = () => {
  const { todo } = useBellItems();
  return computed(() => attentionBadges(todo.value));
};
