// Medical records. Reads and writes go through RPCs (supabase/migrations/20261021*.sql),
// which check the "medical" permission at the branch.
export * from "./diagnosisTerms";
export * from "./errors";
export * from "./rules";
export * from "./vaccineTypes";
export * from "./visits";
export * from "./vaccinations";
export * from "./billing";
export * from "./flags";
