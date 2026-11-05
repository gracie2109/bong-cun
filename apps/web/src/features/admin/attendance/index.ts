// Public surface of admin/attendance: what other features may import. Everything else stays private.
export { usePendingLeaveCount, useShiftTemplates } from "./queries";
export { default as ClockButton } from "./clock/ClockButton.vue";
