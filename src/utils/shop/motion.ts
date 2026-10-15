/** The shop's page size: cards of one loaded page enter in a stagger, counted from that page's first card. */
const PAGE = 24;
/** Cards after this many enter together, so a long page does not keep animating. */
const MAX_STAGGER = 10;

/** The stagger slot (CSS --i) of a card in a list that grows a page at a time. */
export const revealIndex = (index: number): number => Math.min(index % PAGE, MAX_STAGGER);
