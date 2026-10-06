import { createI18n } from 'vue-i18n'
import pluralRules from './rules/pluralization'
import numberFormats from './rules/numbers'
import datetimeFormats from './rules/datetime'
import vi from './locales/vi.json'
import en from './locales/en.json';
import { USER_LOCALE } from "@/lib/constants";
import { env } from "@/config/env";

export default createI18n({
  locale: USER_LOCALE || env.defaultLocale,
  fallbackLocale: env.fallbackLocale,
  legacy: false,
  globalInjection: true,
  messages: { vi, en },
  ...numberFormats,
  ...datetimeFormats,
  pluralRules,
})
