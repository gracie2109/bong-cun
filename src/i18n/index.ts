import { tryUseNuxtApp } from "#imports";

// The vue-i18n instance is owned by @nuxtjs/i18n (one per request on the
// server). Plain modules such as toasts and zod schemas cannot call useI18n(),
// so they translate through this accessor, which keeps the old
// `i18n.global.t(...)` call shape. Outside a Nuxt context it returns the key.
const t = (key: string, named?: Record<string, unknown>): string => {
  const i18n = tryUseNuxtApp()?.$i18n;
  if (!i18n) return key;
  return named ? i18n.t(key, named) : i18n.t(key);
};

export default { global: { t } };
