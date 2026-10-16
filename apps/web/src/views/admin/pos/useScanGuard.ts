// A barcode scanner types like a very fast keyboard and ends with Enter. In the payment dialog
// that would add the code to an amount and press OK, so such a burst is undone instead.
const SCAN_KEY_GAP_MS = 50;
const SCAN_MIN_CHARS = 6;

/**
 * Keydown handler for a form: a run of at least SCAN_MIN_CHARS characters typed under
 * SCAN_KEY_GAP_MS apart and ended by Enter puts back what the form held before the run, keeps the
 * Enter from reaching the dialog, and calls `onBlocked`.
 */
export const useScanGuard = <T>(snapshot: () => T, restore: (value: T) => void, onBlocked: () => void) => {
  let lastKeyAt = Number.NEGATIVE_INFINITY;
  let burstLength = 0;
  let beforeBurst: T | null = null;

  return (event: KeyboardEvent) => {
    const fast = event.timeStamp - lastKeyAt < SCAN_KEY_GAP_MS;
    lastKeyAt = event.timeStamp;

    if (event.key === "Enter") {
      if (fast && burstLength >= SCAN_MIN_CHARS && beforeBurst !== null) {
        event.preventDefault();
        restore(beforeBurst);
        onBlocked();
      }
      burstLength = 0;
      beforeBurst = null;
      return;
    }
    if (event.key.length !== 1) return;
    if (!fast) {
      burstLength = 0;
      beforeBurst = snapshot();
    }
    burstLength += 1;
  };
};
