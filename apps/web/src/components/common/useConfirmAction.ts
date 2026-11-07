import { ref, shallowRef } from "vue";

export type ConfirmOptions = {
  title: string;
  message?: string;
  okText?: string;
  /** A red OK button, for deleting, overwriting or publishing. */
  danger?: boolean;
  /** Shows an optional text box; what the person typed comes back as `reason`. */
  reason?: { label: string; placeholder?: string };
};

export type ConfirmResult = { ok: boolean; reason: string | null };

/**
 * Asks "are you sure?" and waits for the answer: `const { ok, reason } = await confirm.ask({...})`.
 * Put one `<ConfirmReasonDialog :confirm="confirm" />` next to the code that asks.
 */
export const useConfirmAction = () => {
  const open = ref(false);
  const options = shallowRef<ConfirmOptions>({ title: "" });
  let pending: ((result: ConfirmResult) => void) | null = null;

  const settle = (ok: boolean, reason: string | null = null) => {
    open.value = false;
    const resolve = pending;
    pending = null;
    resolve?.({ ok, reason: ok ? reason?.trim() || null : null });
  };

  const ask = (next: ConfirmOptions): Promise<ConfirmResult> =>
    new Promise((resolve) => {
      pending?.({ ok: false, reason: null });
      pending = resolve;
      options.value = next;
      open.value = true;
    });

  return { open, options, ask, settle };
};

export type ConfirmAction = ReturnType<typeof useConfirmAction>;
