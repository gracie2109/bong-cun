// Prints an HTML document through a hidden iframe, so the admin page itself is untouched.

const FRAME_STYLE = "position:fixed;right:0;bottom:0;width:0;height:0;border:0;";
const PRINT_DELAY_MS = 100;
const FRAME_LIFETIME_MS = 60_000;

export const printHtml = (html: string): void => {
  const frame = document.createElement("iframe");
  frame.setAttribute("aria-hidden", "true");
  frame.style.cssText = FRAME_STYLE;
  document.body.appendChild(frame);
  const doc = frame.contentDocument;
  if (!doc || !frame.contentWindow) {
    frame.remove();
    return;
  }
  doc.open();
  doc.write(html);
  doc.close();
  const view = frame.contentWindow;
  view.onafterprint = () => frame.remove();
  setTimeout(() => {
    view.focus();
    view.print();
    // Browsers that never fire afterprint still drop the frame eventually.
    setTimeout(() => frame.remove(), FRAME_LIFETIME_MS);
  }, PRINT_DELAY_MS);
};

export const escapeHtml = (text: string | number | null | undefined): string =>
  String(text ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
