import pluralRules from "./rules/pluralization";
import numberFormats from "./rules/numbers";
import datetimeFormats from "./rules/datetime";

export default defineI18nConfig(() => ({
  legacy: false,
  fallbackLocale: "en",
  numberFormats,
  datetimeFormats,
  pluralRules,
}));
