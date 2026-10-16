export type SearchViewProps = {
  placeholder?: string;
  /** Filters that differ from their default; shown as a badge on the filter button and enables Clear. */
  activeCount?: number;
  /** Spins the refresh icon and locks the button. */
  refreshing?: boolean;
  showSearch?: boolean;
  showClear?: boolean;
  /** Defaults to true when the screen fills the `filters` slot. */
  showFilter?: boolean;
  showRefresh?: boolean;
  /** Width of the filter popover (any CSS length). */
  filterWidth?: string;
};

export type SearchViewEmits = {
  /** The search box value was committed now (Enter) instead of waiting for the debounce. */
  (event: "apply"): void;
  (event: "reset-filters"): void;
  (event: "clear"): void;
  (event: "refresh"): void;
  (event: "open-filters"): void;
};
