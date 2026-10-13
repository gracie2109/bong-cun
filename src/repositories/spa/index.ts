// Spa appointments: bookings with one ticket per pet and service, each with a staff member and
// a table. Reads and writes go through RPCs (supabase/migrations/2026101303*.sql
// and 20261013040000_spa_check_in.sql), which check the "schedule" permission at the branch.
export * from "./appointments";
export * from "./board";
export * from "./rules";
export * from "./settings";
