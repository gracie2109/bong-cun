# Structuring admin views

Admin pages live in `src/views/admin/<feature>/`. A page (`Index.vue`, a `*Sheet.vue`)
wires data, state and child components together; it should not hold the details of each.
These are the conventions the existing pages follow.

## Where things go

| Kind | Location | Example |
| --- | --- | --- |
| Server data (queries, mutations) | `src/queries/`, `src/repositories/` | `usePetsList` |
| State and logic of one page | `use<Thing>.ts` next to the page | `pets/usePetsFilters.ts`, `pos/usePosCart.ts` |
| Pure helpers of one feature | `<thing>.ts` next to the page | `inventory/documents/documentLines.ts` |
| Part of one page's UI | next to the page, or `components/` of the feature | `pets/components/PetRow.vue` |
| UI used by 3+ pages | `src/components/common/` | `TablePager.vue` |

### Shared pieces for list pages

List pages (a filter bar, a table, paging) are built from these; reuse them before writing new ones.

| Piece | For |
| --- | --- |
| `composables/usePagedSearch` | Debounced search box + paging that returns to page 1 when the search or a filter changes |
| `composables/usePagedList` | `rows`, `total` and `pageCount` of a paginated query |
| `components/common/PagedTableCard` | The card around a table, with "showing n of total" and the page buttons |
| `components/common/TableStateRows` | Skeleton rows while loading and the empty message |
| `components/common/TablePager` | Previous / next buttons on their own |
| `components/common/ChipPicker` | Choosing several options as toggleable chips |
| `lib/listing` | `FILTER_ALL`, `SEARCH_DEBOUNCE_MS`, `SEARCH_DEBOUNCE_FAST_MS` |

A list page then reads as: a composable for its filters (`use<Things>Filters`), a filter bar component,
a row component (`<Thing>Row`), and an `Index.vue` that wires them with the pieces above.

Keep it at the smallest scope that works. Something used by one page stays beside that page;
promote it to a shared folder only when a third caller exists. No catch-all `utils`.

## When to split

Split when it gives the page a clearer job, not to reach a line count. As a rule of thumb,
look at a page again past ~250 lines of template plus script.

- **Extract a composable** when the script mixes filters, paging, cart or form state with the wiring.
  Return refs and computed values (do not destructure them into plain values), and take what it
  depends on as arguments or getters (`permissions: () => readonly Permission[]`).
- **Extract a component** for a block repeated in a `v-for` (a table row, a cart line), a block with
  its own state or handlers (a filter bar, a group of fields), or a block used on several pages.
- **Extract a pure function** for calculations and validation. They need no Vue and are easy to test.
- **Leave it inline** when the markup is a few static lines, or a component would need more than
  about six props to work.

## Component contracts

- Input goes in through props; changes come out as events named for what happened
  (`archive`, `restore`, `setCell`), not for how the parent will react.
- Use `defineModel` for state the child edits on behalf of the parent (`v-model:search`).
- A component that only needs an id and an action may call its own mutation hook
  (`RoleStaffSection` removes a holder itself) instead of emitting through several layers.
- Do not pass a whole composable's return value down as a prop; pass the few values the child reads.

## Named values

Statuses, limits, page sizes, debounce times and routes get a named constant
(`PAGE_SIZE`, `SEARCH_DEBOUNCE_MS`). Put it where it is used; export it only when another
file needs the same value (`ALL` and `PET_STATUSES` in `usePetsFilters.ts`).

## Checking a change

1. `npx vue-tsc --noEmit -p .nuxt/tsconfig.app.json` (the root `tsconfig.json` has no files,
   so running `vue-tsc` without `-p` checks nothing). Compare against the errors that were
   there before the change.
2. Run the page and exercise it: filters, paging, create/edit/delete, and the empty and loading states.
3. A split must not change behavior. If a refactor needs a behavior change, make it a separate commit.
