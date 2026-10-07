<template>
  <Header>
    <h1 class="font-semibold flex items-center gap-2">
      <router-link :to="{ name: 'pets' }" class="flex items-center gap-2 text-muted-foreground hover:text-primary">
        <PawPrint class="size-4 text-primary" />
        {{ $t("petCare.pets.title") }}
      </router-link>
      <ChevronRight class="size-4 text-muted-foreground" />
      <span>{{ pet?.name ?? "" }}</span>
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <PetsNav />

      <div v-if="petQuery.isPending.value" class="space-y-4">
        <Skeleton class="h-40 w-full" />
        <Skeleton class="h-64 w-full" />
      </div>

      <div v-else-if="!pet" class="rounded-xl border bg-white p-10 text-center text-muted-foreground">
        {{ $t("petCare.pets.detail.notFound") }}
      </div>

      <template v-else>
        <div class="flex flex-wrap items-center gap-5 rounded-xl border bg-white p-5">
          <Avatar class="size-24">
            <AvatarImage v-if="pet.photoUrl" :src="pet.photoUrl" />
            <AvatarFallback class="bg-primary/15 text-2xl font-semibold text-primary">
              {{ initials(pet.name) }}
            </AvatarFallback>
          </Avatar>

          <div class="min-w-0 flex-1 space-y-2">
            <div class="flex flex-wrap items-center gap-2">
              <h2 class="text-2xl font-bold">{{ pet.name }}</h2>
              <span
                class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
                :class="pet.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-muted text-muted-foreground'"
              >
                {{ $t(`petCare.status.${pet.status}`) }}
              </span>
            </div>
            <p class="flex flex-wrap items-center gap-x-2 text-sm text-muted-foreground">
              <Icon v-if="pet.speciesIcon" :icon="pet.speciesIcon" class="size-4" />
              {{ [pet.speciesName, pet.breed].filter(Boolean).join(" · ") }}
              <span>· {{ $t(`petCare.sex.${pet.sex}`) }}</span>
              <span v-if="pet.neutered">· {{ $t("petCare.pets.neutered") }}</span>
              <span v-if="pet.birthDate">
                · {{ $t("petCare.pets.detail.born", { date: formatDate(pet.birthDate) }) }}
                ({{ ageText }})
              </span>
            </p>
            <p v-if="pet.microchip" class="text-xs text-muted-foreground">
              Microchip: {{ pet.microchip }}
            </p>
            <div v-if="pet.allergies || pet.behaviorNotes" class="flex flex-wrap gap-2">
              <span v-if="pet.allergies" class="rounded-full bg-red-100 px-3 py-1 text-xs font-semibold text-red-700">
                {{ $t("petCare.pets.tagAllergy") }}: {{ pet.allergies }}
              </span>
              <span v-if="pet.behaviorNotes" class="rounded-full bg-orange-100 px-3 py-1 text-xs font-semibold text-orange-700">
                {{ pet.behaviorNotes }}
              </span>
            </div>
          </div>

          <div class="flex flex-wrap gap-2">
            <Button variant="outline" as-child>
              <router-link :to="{ name: 'petPrices', query: { speciesId: pet.speciesId, weight: latestWeight?.weightKg } }">
                <Banknote class="mr-2 size-4" />
                {{ $t("petCare.pets.detail.checkPrice") }}
              </router-link>
            </Button>
            <Button v-if="canUpdate" variant="outline" @click="editOpen = true">
              <Pencil class="mr-2 size-4" />
              {{ $t("petCare.pets.detail.editProfile") }}
            </Button>
            <DropdownMenu v-if="canUpdate">
              <DropdownMenuTrigger as-child>
                <Button variant="ghost" size="icon"><EllipsisVertical class="size-4" /></Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem v-if="pet.status !== 'active'" @click="changeStatus('active')">
                  {{ $t("petCare.common.restore") }}
                </DropdownMenuItem>
                <DropdownMenuItem v-if="pet.status === 'active'" @click="changeStatus('archived')">
                  {{ $t("petCare.common.archive") }}
                </DropdownMenuItem>
                <DropdownMenuItem v-if="pet.status === 'active'" @click="changeStatus('deceased')">
                  {{ $t("petCare.pets.detail.markDeceased") }}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>

        <div class="grid gap-5 xl:grid-cols-[24rem_minmax(0,1fr)]">
          <div class="space-y-5">
            <div class="space-y-3 rounded-xl border bg-white p-4">
              <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                {{ $t("petCare.pets.detail.owners") }}
              </h3>
              <p v-if="pet.owners.length === 0" class="text-sm text-muted-foreground">
                {{ $t("petCare.pets.noOwner") }}
              </p>
              <ul class="divide-y">
                <li v-for="owner in pet.owners" :key="owner.customer.id" class="flex items-center gap-3 py-2">
                  <Avatar class="size-9">
                    <AvatarFallback class="bg-primary/15 text-sm font-semibold text-primary">
                      {{ initials(owner.customer.fullName) }}
                    </AvatarFallback>
                  </Avatar>
                  <div class="min-w-0 flex-1">
                    <p class="truncate font-semibold">{{ owner.customer.fullName }}</p>
                    <p class="text-xs text-muted-foreground">{{ owner.customer.phone }}</p>
                  </div>
                  <span class="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
                    {{ owner.role === "primary" ? $t("petCare.pets.detail.primary") : $t("petCare.pets.detail.coOwner") }}
                  </span>
                </li>
              </ul>
              <p class="text-xs text-muted-foreground">{{ $t("petCare.pets.detail.ownersNote") }}</p>
            </div>

            <div class="space-y-3 rounded-xl border bg-white p-4">
              <div class="flex items-center justify-between">
                <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  {{ $t("petCare.pets.detail.weight") }}
                </h3>
                <Button v-if="canUpdate" size="sm" variant="outline" @click="weightOpen = !weightOpen">
                  <Plus class="mr-1 size-4" />
                  {{ $t("petCare.pets.detail.addWeight") }}
                </Button>
              </div>

              <p v-if="latestWeight" class="text-4xl font-bold">
                {{ $t("petCare.common.kg", { n: latestWeight.weightKg }) }}
              </p>
              <p v-else class="text-sm text-muted-foreground">{{ $t("petCare.pets.noWeight") }}</p>
              <p v-if="latestWeight" class="text-xs font-medium" :class="bracket ? 'text-primary' : 'text-amber-600'">
                {{
                  bracket
                    ? $t("petCare.pets.detail.currentBracket", { label: bracket.label })
                    : $t("petCare.pets.fields.noBracket")
                }}
              </p>

              <form v-if="canUpdate && weightOpen" class="space-y-2 rounded-lg border bg-muted/30 p-3" @submit.prevent="submitWeight">
                <div class="space-y-1">
                  <Label for="weight-kg">{{ $t("petCare.pets.detail.weightKg") }}</Label>
                  <Input id="weight-kg" v-model="weightInput" type="number" step="0.1" min="0" inputmode="decimal" />
                </div>
                <div class="space-y-1">
                  <Label for="weight-note">{{ $t("petCare.pets.detail.weightNote") }}</Label>
                  <Input id="weight-note" v-model="weightNote" />
                </div>
                <div class="flex justify-end gap-2">
                  <Button type="button" size="sm" variant="outline" @click="weightOpen = false">
                    {{ $t("petCare.common.cancel") }}
                  </Button>
                  <Button type="submit" size="sm" :disabled="addWeight.isPending.value || !weightValid">
                    {{ $t("petCare.common.save") }}
                  </Button>
                </div>
              </form>

              <WeightSparkline v-if="pet.weights.length > 1" :weights="pet.weights" />

              <div v-if="pet.weights.length" class="space-y-1">
                <p class="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
                  {{ $t("petCare.pets.detail.weightHistory") }}
                </p>
                <ul class="max-h-40 divide-y overflow-y-auto text-sm">
                  <li v-for="log in pet.weights" :key="log.id" class="flex items-center justify-between py-1.5">
                    <span>{{ formatDate(log.measuredAt) }}</span>
                    <span class="font-medium">{{ $t("petCare.common.kg", { n: log.weightKg }) }}</span>
                  </li>
                </ul>
              </div>
            </div>
          </div>

          <div class="rounded-xl border bg-white p-4">
            <Tabs default-value="history">
              <TabsList>
                <TabsTrigger value="history">{{ $t("petCare.pets.detail.tabHistory") }}</TabsTrigger>
                <TabsTrigger value="upcoming">{{ $t("petCare.pets.detail.tabUpcoming") }}</TabsTrigger>
                <TabsTrigger value="boarding">{{ $t("petCare.pets.detail.tabBoarding") }}</TabsTrigger>
                <TabsTrigger value="notes">{{ $t("petCare.pets.detail.tabNotes") }}</TabsTrigger>
                <TabsTrigger value="medical" disabled>{{ $t("petCare.pets.detail.tabMedical") }}</TabsTrigger>
              </TabsList>
              <TabsContent v-for="tab in placeholderTabs" :key="tab" :value="tab">
                <p class="py-10 text-center text-sm text-muted-foreground">
                  {{ $t("petCare.pets.detail.comingSoon") }}
                </p>
              </TabsContent>
            </Tabs>
          </div>
        </div>

        <PetEditSheet v-model:open="editOpen" :pet="pet" />
      </template>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useRoute } from "vue-router";
import { Icon } from "@iconify/vue";
import {
  Banknote,
  ChevronRight,
  EllipsisVertical,
  PawPrint,
  Pencil,
  Plus,
} from "lucide-vue-next";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { usePermission } from "@/composables/usePermission";
import { useAddPetWeight, usePet, useSetPetStatus } from "@/queries/pets";
import { useWeightBrackets } from "@/queries/weightBrackets";
import type { PetStatus } from "@/repositories/pets";
import { findBracket } from "@/repositories/weightBrackets";
import { ContentWrap, Header } from "@/views/admin/components";
import PetEditSheet from "../components/PetEditSheet.vue";
import { ageOf, formatDate, initials } from "../format";
import PetsNav from "../PetsNav.vue";
import WeightSparkline from "./WeightSparkline.vue";

const placeholderTabs = ["history", "upcoming", "boarding", "notes"];

const { t } = useI18n();
const route = useRoute();
const { canUpdate } = usePermission("pets");
const petId = computed(() => String(route.params.petId));

const petQuery = usePet(petId);
const pet = computed(() => petQuery.data.value ?? null);

const speciesId = computed(() => pet.value?.speciesId);
const bracketsQuery = useWeightBrackets(speciesId, { enabled: computed(() => !!speciesId.value) });

// Weights come newest first from the repository.
const latestWeight = computed(() => pet.value?.weights[0] ?? null);
const bracket = computed(() =>
  latestWeight.value ? findBracket(bracketsQuery.data.value ?? [], latestWeight.value.weightKg) : undefined
);

const ageText = computed(() => {
  const age = ageOf(pet.value?.birthDate ?? null);
  if (!age) return t("petCare.pets.ageUnknown");
  if (age.years === 0) return t("petCare.pets.ageMonths", { m: age.months });
  return age.months === 0
    ? t("petCare.pets.ageYears", { y: age.years })
    : t("petCare.pets.ageYearsMonths", { y: age.years, m: age.months });
});

const editOpen = ref(false);
const weightOpen = ref(false);
const weightInput = ref("");
const weightNote = ref("");
const weightValid = computed(() => weightInput.value !== "" && Number(weightInput.value) > 0);

const addWeight = useAddPetWeight();
const setStatus = useSetPetStatus();

const submitWeight = async () => {
  if (!weightValid.value) return;
  try {
    await addWeight.mutateAsync({
      petId: petId.value,
      weightKg: Number(weightInput.value),
      note: weightNote.value.trim() || null,
    });
    weightInput.value = "";
    weightNote.value = "";
    weightOpen.value = false;
  } catch {
    // the mutation already showed the failure toast; keep the form open
  }
};

const changeStatus = async (status: PetStatus) => {
  try {
    await setStatus.mutateAsync({ id: petId.value, status });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
