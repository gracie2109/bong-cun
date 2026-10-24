import { onBeforeUnmount, onMounted } from "vue";

type Editor = { editing: { value: boolean }; cancel: () => void; isDirty: { value: boolean } };

/** Esc leaves edit mode when nothing else (a dialog, a menu) is open and there is nothing to lose. */
export const useEditEscape = (editor: Editor) => {
  const onKey = (event: KeyboardEvent) => {
    if (event.key !== "Escape" || !editor.editing.value || editor.isDirty.value || event.defaultPrevented) return;
    if (document.querySelector('[role="dialog"], [role="alertdialog"], [role="menu"]')) return;
    editor.cancel();
  };
  onMounted(() => window.addEventListener("keydown", onKey));
  onBeforeUnmount(() => window.removeEventListener("keydown", onKey));
};
