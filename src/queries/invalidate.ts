import type { QueryClient } from "@tanstack/vue-query";
import {
  permissionKeys,
  petComboKeys,
  petProfileKeys,
  petServiceKeys,
  roleKeys,
  servicePriceKeys,
  speciesKeys,
  staffKeys,
  weightBracketKeys,
} from "./keys";

// Species, brackets, services, prices and combos reference each other through join tables
// (and cascade deletes), so a change to one can change what the others show.
// Refreshing the whole catalog is simple and cheap for an admin tool.
export const invalidateCatalog = (queryClient: QueryClient) =>
  Promise.all([
    queryClient.invalidateQueries({ queryKey: speciesKeys.all }),
    queryClient.invalidateQueries({ queryKey: weightBracketKeys.all }),
    queryClient.invalidateQueries({ queryKey: petProfileKeys.all }),
    queryClient.invalidateQueries({ queryKey: petServiceKeys.all }),
    queryClient.invalidateQueries({ queryKey: servicePriceKeys.all }),
    queryClient.invalidateQueries({ queryKey: petComboKeys.all }),
  ]);

// Renaming a permission cascades into every role that grants it, and renaming a role into
// every staff assignment that holds it.
export const invalidateAccess = (queryClient: QueryClient) =>
  Promise.all([
    queryClient.invalidateQueries({ queryKey: permissionKeys.all }),
    queryClient.invalidateQueries({ queryKey: roleKeys.all }),
    queryClient.invalidateQueries({ queryKey: staffKeys.all }),
  ]);
