import type { NotificationLink } from "./types";

// The route a notification opens: the name of a named route and its query. Nothing here is a URL,
// so a link stored in the database can never send someone to another site.
export const notificationRoute = (link: NotificationLink | null): { name: string; query: Record<string, string> } | null => {
  if (!link || !/^[A-Za-z][A-Za-z0-9]{0,63}$/.test(link.name)) return null;
  return { name: link.name, query: link.query };
};
