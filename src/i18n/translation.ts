import { nextTick} from 'vue'
import i18n from './index'
import { getLocalStorage, setLocalStorage } from '@/lib/utils'
import { env } from '@/config/env'

const Trans = {
  get defaultLocale() {
    return env.defaultLocale
  },

  get supportedLocales() {
    return env.supportedLocales
  },

  get currentLocale() {
    return i18n.global.locale.value
  },

  set currentLocale(newLocale) {
    i18n.global.locale.value = newLocale
  },

  async switchLanguage(newLocale: any) {
    await Trans.loadLocaleMessages(newLocale);
    Trans.currentLocale = newLocale;

    (document.querySelector('html') as HTMLElement).setAttribute('lang', newLocale);
    setLocalStorage('user-locale', newLocale)
  },

  async loadLocaleMessages(locale: any) {
    if (!i18n.global.availableLocales.includes(locale)) {
      const messages = await import(`@/i18n/locales/${locale}.json`)
      i18n.global.setLocaleMessage(locale, messages.default)
    }

    return nextTick()
  },

  isLocaleSupported(locale: any) {
    return Trans.supportedLocales.includes(locale)
  },

  getUserLocale() {
    const locale = window.navigator.language
      //@ts-ignore
      || window.navigator.userLanguage
      || Trans.defaultLocale

    return {
      locale,
      localeNoRegion: locale.split('-')[0],
    }
  },

  getPersistedLocale() {
    const a = getLocalStorage('user-locale');
    const persistedLocale = JSON.parse(a)
    if (!persistedLocale) return Trans.defaultLocale
    if (Trans.isLocaleSupported(persistedLocale)) {
      return persistedLocale
    }
    else {
      return null
    }
  },

  guessDefaultLocale() {
    const userPersistedLocale = Trans.getPersistedLocale()
    if (userPersistedLocale) {
      return userPersistedLocale
    }

    const userPreferredLocale = Trans.getUserLocale()

    if (Trans.isLocaleSupported(userPreferredLocale.locale)) {
      return userPreferredLocale.locale
    }

    if (Trans.isLocaleSupported(userPreferredLocale.localeNoRegion)) {
      return userPreferredLocale.localeNoRegion
    }

    return Trans.defaultLocale
  },

  async routeMiddleware(to: any, _from: any, next: any) {
    const a = getLocalStorage('user-locale');
    const paramLocale = JSON.parse(a)
    
    if (!Trans.isLocaleSupported(paramLocale)) {
      return next(Trans.guessDefaultLocale())
    }

    await Trans.switchLanguage(paramLocale)

    return next()
  },

  i18nRoute(to: any) {
    return {
      ...to,
      params: {
        locale: Trans.currentLocale,
        ...to.params,
      },
    }
  },
}

export default Trans
