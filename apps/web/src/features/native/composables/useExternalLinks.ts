import { Browser } from "@capacitor/browser";
import { classifyLink } from "../helpers/links";

/**
 * Opens outside web links and new-tab links in the system browser instead of inside the WebView.
 * tel:, mailto: and app links (Zalo...) are left alone: Capacitor's WebView already hands them to Android.
 */
export const useExternalLinks = () => {
  const onClick = (event: MouseEvent) => {
    const anchor = (event.target as Element | null)?.closest?.("a[href]") as HTMLAnchorElement | null;
    if (!anchor || event.defaultPrevented) return;

    const target = classifyLink(anchor.getAttribute("href") ?? "", window.location.origin, anchor.target === "_blank");
    if (target !== "browser") return;

    event.preventDefault();
    Browser.open({ url: anchor.href });
  };

  const listen = () => document.addEventListener("click", onClick, true);

  return { listen };
};
