// Safety checks before a migration is written. Any message returned stops the sync.
export const EXPECTED_PROVINCES = 34;
export const FIRST_COMMUNES = 3321;
const MAX_COUNT_DRIFT = 0.02;
const MAX_RETIRED = 50;

const countActive = (units, level) => Object.values(units).filter((unit) => unit.level === level && unit.status === "active").length;

export const activeCounts = (units) => ({ provinces: countActive(units, "province"), communes: countActive(units, "commune") });

/**
 * @param {{ catalog: object|null, previous: object, units: object, ghn: object, nextUnits: object, retired: number, allowCountChange: boolean }} input
 * `units` is what the snapshot lists; `nextUnits` is the state after the change.
 */
export const runChecks = ({ catalog, previous, units, ghn, nextUnits, retired, allowCountChange }) => {
  const errors = [];
  if (!catalog) return ["the snapshot has no catalog line"];
  if (previous.catalog && catalog.effective_on < previous.catalog.effective_on) {
    errors.push(`the snapshot's catalog (${catalog.effective_on}) is older than the one already synced (${previous.catalog.effective_on})`);
  }

  const now = activeCounts(units);
  const before = activeCounts(previous.units);
  if (!allowCountChange) {
    if (now.provinces !== EXPECTED_PROVINCES) errors.push(`${now.provinces} active provinces, expected ${EXPECTED_PROVINCES}`);
    const reference = before.communes || FIRST_COMMUNES;
    if (Math.abs(now.communes - reference) > reference * MAX_COUNT_DRIFT) {
      errors.push(`${now.communes} active communes, more than ${MAX_COUNT_DRIFT * 100}% away from ${reference}`);
    }
    if (retired > MAX_RETIRED) errors.push(`${retired} units would retire at once (limit ${MAX_RETIRED})`);
  }

  for (const [code, unit] of Object.entries(units)) {
    if (unit.level !== "commune" || unit.status !== "active") continue;
    const parent = units[unit.parent_code];
    if (!parent || parent.level !== "province" || parent.status !== "active") {
      errors.push(`commune ${code} (${unit.full_name}) has no active province as parent`);
    }
  }
  for (const code of Object.keys(ghn)) {
    if (!(code in nextUnits)) errors.push(`GHN mapping points at ${code}, which is not cached`);
  }
  return errors;
};
