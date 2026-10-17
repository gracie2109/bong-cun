// Public surface of admin/medical: what other features may import. Everything else stays private.
export { default as VaccineBookList } from "./book/VaccineBookList.vue";
export { default as VaccineTypeSelect } from "./book/VaccineTypeSelect.vue";
export { default as VoidDoseDialog } from "./book/VoidDoseDialog.vue";
export { useVaccineTypeOptions } from "./book/useVaccineTypeOptions";
export { default as PetHealthFlagsBanner } from "./flags/PetHealthFlagsBanner.vue";
export { nextDue, suggestedDoseNo } from "./nextDue";
export { notifyMedicalFailure } from "./queries/medical";
export { useMedicalQueue, usePetMedicalHistory } from "./queries/medicalVisits";
export { useAddExternalVaccine, useMedicalReminders, usePetBook, useVoidVaccine } from "./queries/vaccinations";
