// Prints an 80 mm retail receipt through a hidden iframe, so the admin page itself is untouched.
import type { Branch } from "@/repositories/branches";
import type { InvoiceDetail } from "@/repositories/pos";
import { dateTime, money } from "./format";

type Translate = (key: string, values?: Record<string, unknown>) => string;

const escapeHtml = (text: string | number | null | undefined): string =>
  String(text ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");

const row = (label: string, value: string, strong = false): string =>
  `<tr class="${strong ? "strong" : ""}"><td>${escapeHtml(label)}</td><td class="r">${escapeHtml(value)}</td></tr>`;

export const receiptHtml = (invoice: InvoiceDetail, branch: Branch | null, t: Translate): string => {
  const lines = invoice.lines
    .map((line) => {
      const pet = line.petName ? ` · ${escapeHtml(line.petName)}` : "";
      return `<tr><td colspan="2">${escapeHtml(line.name)}${pet}</td></tr>
        <tr class="sub"><td>${escapeHtml(line.qty)} × ${escapeHtml(money(line.unitPrice))}</td><td class="r">${escapeHtml(money(line.amount))}</td></tr>`;
    })
    .join("");
  const payments = invoice.payments
    .map((payment) => row(t(`pos.method.${payment.method}`), money(payment.amount)))
    .join("");

  return `<!doctype html><html><head><meta charset="utf-8"><title>${escapeHtml(invoice.code)}</title>
<style>
  @page { size: 80mm auto; margin: 4mm; }
  body { font-family: "Be Vietnam Pro", Arial, sans-serif; font-size: 12px; color: #000; width: 72mm; margin: 0; }
  h1 { font-size: 15px; text-align: center; margin: 0 0 2px; }
  .c { text-align: center; } .r { text-align: right; white-space: nowrap; }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 1px 0; vertical-align: top; }
  .sub td { color: #333; padding-bottom: 4px; }
  .strong td { font-weight: 700; font-size: 13px; }
  hr { border: 0; border-top: 1px dashed #000; margin: 6px 0; }
  .muted { color: #444; font-size: 11px; }
</style></head><body>
  <h1>${escapeHtml(branch?.name ?? "BongCun")}</h1>
  ${branch?.address ? `<p class="c muted">${escapeHtml(branch.address)}</p>` : ""}
  ${branch?.phone ? `<p class="c muted">${escapeHtml(branch.phone)}</p>` : ""}
  <hr>
  <p class="c"><strong>${escapeHtml(t("pos.receipt.title"))}</strong><br>${escapeHtml(invoice.code)}</p>
  <p class="muted">${escapeHtml(dateTime(invoice.createdAt))}<br>
    ${escapeHtml(t("pos.receipt.cashier"))}: ${escapeHtml(invoice.cashierName)}<br>
    ${escapeHtml(t("pos.receipt.customer"))}: ${escapeHtml(invoice.customerName ?? t("pos.walkIn"))}
    ${invoice.customerPhone ? ` · ${escapeHtml(invoice.customerPhone)}` : ""}</p>
  <hr>
  <table>${lines}</table>
  <hr>
  <table>
    ${row(t("pos.subtotal"), money(invoice.subtotal))}
    ${invoice.discountAmount ? row(t("pos.discount"), `-${money(invoice.discountAmount)}`) : ""}
    ${row(t("pos.total"), money(invoice.total), true)}
    ${payments}
    ${invoice.changeAmount ? row(t("pos.change"), money(invoice.changeAmount)) : ""}
  </table>
  ${invoice.status === "cancelled" ? `<hr><p class="c"><strong>${escapeHtml(t("pos.status.cancelled"))}</strong></p>` : ""}
  <hr>
  <p class="c muted">${escapeHtml(t("pos.receipt.thanks"))}</p>
</body></html>`;
};

export const printReceipt = (invoice: InvoiceDetail, branch: Branch | null, t: Translate) => {
  const frame = document.createElement("iframe");
  frame.setAttribute("aria-hidden", "true");
  frame.style.cssText = "position:fixed;right:0;bottom:0;width:0;height:0;border:0;";
  document.body.appendChild(frame);
  const doc = frame.contentDocument;
  if (!doc || !frame.contentWindow) {
    frame.remove();
    return;
  }
  doc.open();
  doc.write(receiptHtml(invoice, branch, t));
  doc.close();
  const view = frame.contentWindow;
  view.onafterprint = () => frame.remove();
  setTimeout(() => {
    view.focus();
    view.print();
    // Browsers that never fire afterprint still drop the frame eventually.
    setTimeout(() => frame.remove(), 60_000);
  }, 100);
};
