import { computed, reactive, ref, watch } from "vue";
import { refDebounced } from "@vueuse/core";
import { useI18n } from "vue-i18n";
import { useCustomerSearch } from "@/queries/customers";
import { digitsOf, type CustomerMatch } from "@/repositories/customers";
import type { RegisterOwner } from "@/repositories/pets";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";

const MIN_PHONE_DIGITS = 8;
const MAX_PHONE_DIGITS = 15;
/** A search of this shape is most likely a phone number. */
const PHONE_LIKE = /^[\d\s+.-]{8,}$/;

/** The owner of a new pet: an existing customer picked from a search, or a new one typed in. */
export const useOwnerPicker = () => {
  const { t } = useI18n();

  const searchInput = ref("");
  const selected = ref<CustomerMatch | null>(null);
  const newOwner = reactive({ fullName: "", phone: "", email: "" });

  const searchText = refDebounced(searchInput, SEARCH_DEBOUNCE_MS);
  const matchesQuery = useCustomerSearch(searchText);
  const matches = computed(() => matchesQuery.data.value ?? []);

  // Only a new customer needs typed details; a picked one already has them.
  const errors = computed(() => {
    if (selected.value) return { fullName: null, phone: null };
    const digits = digitsOf(newOwner.phone).length;
    const phoneOk = digits >= MIN_PHONE_DIGITS && digits <= MAX_PHONE_DIGITS;
    return {
      fullName: newOwner.fullName.trim() ? null : t("petCare.pets.registerSheet.errOwner"),
      phone: phoneOk ? null : t("petCare.pets.registerSheet.errPhone"),
    };
  });
  const hasError = computed(() => !!(errors.value.fullName || errors.value.phone));

  // An existing customer picked from the list wins over whatever was typed for a new one.
  const toInput = (): RegisterOwner => {
    const match = selected.value;
    if (match?.customerId) return { id: match.customerId };
    if (match?.userId) return { userId: match.userId };
    return {
      fullName: newOwner.fullName.trim(),
      phone: newOwner.phone.trim(),
      email: newOwner.email.trim() || null,
    };
  };

  const reset = () => {
    searchInput.value = "";
    newOwner.fullName = "";
    newOwner.phone = "";
    newOwner.email = "";
    selected.value = null;
  };

  // A digits-only search is most likely the new customer's phone: carry it over once.
  watch(searchInput, (text) => {
    if (!newOwner.phone && PHONE_LIKE.test(text)) newOwner.phone = text.trim();
  });

  return { searchInput, selected, newOwner, matches, errors, hasError, toInput, reset };
};
