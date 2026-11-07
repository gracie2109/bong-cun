import { computed, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { usePublishWeek as usePublishMutation } from "@/features/admin/attendance/queries";
import { publishWarnings } from "@bongcun/core/attendance";
import type { WeekStatus } from "@bongcun/core/attendance";

/** Asks before publishing (the dialog lists what is still open), then publishes the week. */
export const usePublishWeekAction = (branchId: Ref<string | undefined>, monday: Ref<string>, week: Ref<WeekStatus | undefined>, shifts: Ref<number>) => {
  const { t } = useI18n();
  const confirm = useConfirmAction();
  const mutation = usePublishMutation();

  const warnings = computed(() =>
    publishWarnings({ shifts: shifts.value, pendingRequests: week.value?.pendingRequests ?? 0, missing: week.value?.missingCount ?? 0 })
  );

  const publish = async () => {
    if (!branchId.value) return;
    const lines = warnings.value.map((key) =>
      t(`attendance.publish.warning.${key}`, { pending: week.value?.pendingRequests ?? 0, missing: week.value?.missingCount ?? 0 })
    );
    const answer = await confirm.ask({
      title: t("attendance.publish.confirm.title"),
      message: [t("attendance.publish.confirm.message"), ...lines].join(" "),
      okText: t("attendance.publish.button"),
      danger: true,
      reason: { label: t("attendance.publish.confirm.noteLabel"), placeholder: t("attendance.publish.confirm.noteHint") },
    });
    if (!answer.ok) return;
    mutation.mutate({ branchId: branchId.value, monday: monday.value, rejectNote: answer.reason ?? undefined });
  };

  return { confirm, publish, publishing: mutation.isPending, warnings };
};
