// Compares the snapshot with the state the last migration left, and builds the next state.
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

/** `today` closes the validity of a unit the snapshot no longer lists. */
export const diffState = (previous, units, ghn, today) => {
  const nextUnits = { ...previous.units };
  const changedUnits = [];
  let added = 0;
  let retired = 0;
  for (const [code, unit] of Object.entries(units)) {
    const before = previous.units[code];
    if (before && same(before, unit)) continue;
    if (!before) added += 1;
    else if (before.status === "active" && unit.status === "retired") retired += 1;
    nextUnits[code] = unit;
    changedUnits.push(code);
  }
  for (const [code, before] of Object.entries(previous.units)) {
    if (code in units || before.status === "retired") continue;
    nextUnits[code] = { ...before, status: "retired", effective_to: before.effective_to ?? today };
    changedUnits.push(code);
    retired += 1;
  }

  const nextGhn = { ...previous.ghn };
  const changedGhn = [];
  for (const [code, entry] of Object.entries(ghn)) {
    if (previous.ghn[code] && same(previous.ghn[code], entry)) continue;
    nextGhn[code] = entry;
    changedGhn.push(code);
  }
  for (const [code, before] of Object.entries(previous.ghn)) {
    if (code in ghn || !before.active) continue;
    nextGhn[code] = { ...before, active: false };
    changedGhn.push(code);
  }

  return { nextUnits, nextGhn, changedUnits: sortByLevel(changedUnits, nextUnits), changedGhn: changedGhn.sort(), added, retired };
};

/** Provinces first, then communes, each by code, so a parent is always written before its children. */
const sortByLevel = (codes, units) =>
  [...codes].sort((a, b) => (units[a].level === units[b].level ? (a < b ? -1 : 1) : units[a].level === "province" ? -1 : 1));

export const sortedObject = (object) => Object.fromEntries(Object.entries(object).sort(([a], [b]) => (a < b ? -1 : 1)));
