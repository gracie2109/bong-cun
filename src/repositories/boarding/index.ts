// Pet hotel (boarding). Reads and writes go through RPCs (supabase/migrations/20261020*.sql),
// which check the "boarding" permission at the branch.
export * from "./billing";
export * from "./board";
export * from "./care";
export * from "./checkInOut";
export * from "./errors";
export * from "./kennelTypes";
export * from "./kennels";
export * from "./publicCatalog";
export * from "./rules";
export * from "./stays";
