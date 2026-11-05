// Staff attendance. Reads and writes go through RPCs (supabase/migrations/20261110*.sql), which check
// the "attendance" permission at the branch (self service needs only a row in staff_branches).
export * from "@bongcun/core/attendance";
export * from "./mappers";
export * from "./shifts";
