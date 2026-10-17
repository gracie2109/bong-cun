import { useI18n } from "vue-i18n";
import { splitDuration } from "@bongcun/core/spa";

/** Returns a function turning minutes into "1 giờ 30 phút" (empty when unknown). */
export const useDurationLabel = () => {
  const { t } = useI18n();
  return (totalMinutes: number | null): string => {
    const parts = splitDuration(totalMinutes);
    if (!parts) return "";
    const hours = parts.hours > 0 ? t("client.spa.hours", { n: parts.hours }) : "";
    const minutes = parts.minutes > 0 ? t("client.spa.minutes", { n: parts.minutes }) : "";
    return [hours, minutes].filter(Boolean).join(" ");
  };
};
