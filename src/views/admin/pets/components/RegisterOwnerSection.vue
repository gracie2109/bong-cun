<template>
  <section class="space-y-3">
    <h3 class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">
      {{ $t("petCare.pets.registerSheet.ownerSection") }}
    </h3>

    <div
      v-if="selected"
      class="flex items-center justify-between gap-3 rounded-lg border bg-primary/5 p-3"
    >
      <div class="min-w-0">
        <p class="truncate font-semibold">{{ selected.fullName }}</p>
        <p class="text-xs text-muted-foreground">
          {{ selected.phone }} ·
          {{ $t("petCare.pets.registerSheet.matchPets", { n: selected.petCount }) }}
        </p>
      </div>
      <Button type="button" size="sm" variant="outline" @click="selected = null">
        {{ $t("petCare.pets.registerSheet.change") }}
      </Button>
    </div>

    <template v-else>
      <div class="space-y-2">
        <Label for="register-owner-search">{{ $t("petCare.pets.registerSheet.search") }}</Label>
        <Input
          id="register-owner-search"
          v-model="searchInput"
          :placeholder="$t('petCare.pets.registerSheet.searchPlaceholder')"
        />
      </div>

      <ul v-if="matches.length" class="divide-y rounded-lg border">
        <li
          v-for="match in matches"
          :key="matchKey(match)"
          class="flex items-center justify-between gap-3 px-3 py-2"
        >
          <div class="min-w-0">
            <p class="truncate text-sm font-semibold">{{ match.fullName }}</p>
            <p class="text-xs text-muted-foreground">
              {{ match.phone }} ·
              {{ $t("petCare.pets.registerSheet.matchPets", { n: match.petCount }) }}
            </p>
          </div>
          <Button type="button" size="sm" @click="selected = match">
            {{ $t("petCare.pets.registerSheet.choose") }}
          </Button>
        </li>
      </ul>

      <div class="space-y-3 rounded-lg border border-dashed p-3">
        <p class="text-xs text-muted-foreground">
          <span class="font-semibold text-foreground">
            {{ $t("petCare.pets.registerSheet.newCustomer") }}.
          </span>
          {{ $t("petCare.pets.registerSheet.walkIn") }}
        </p>
        <div class="space-y-2">
          <Label for="register-owner-name">{{ $t("petCare.pets.registerSheet.fullName") }}</Label>
          <Input
            id="register-owner-name"
            v-model="newOwner.fullName"
            :class="{ 'border-destructive': submitted && errors.fullName }"
          />
          <p v-if="submitted && errors.fullName" class="text-xs text-destructive">
            {{ errors.fullName }}
          </p>
        </div>
        <div class="space-y-2">
          <Label for="register-owner-phone">{{ $t("petCare.pets.registerSheet.phone") }}</Label>
          <Input
            id="register-owner-phone"
            v-model="newOwner.phone"
            inputmode="tel"
            :class="{ 'border-destructive': submitted && errors.phone }"
          />
          <p v-if="submitted && errors.phone" class="text-xs text-destructive">
            {{ errors.phone }}
          </p>
        </div>
        <div class="space-y-2">
          <Label for="register-owner-email">{{ $t("petCare.pets.registerSheet.email") }}</Label>
          <Input id="register-owner-email" v-model="newOwner.email" type="email" />
        </div>
      </div>
    </template>
  </section>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { matchKey, type CustomerMatch } from "@/repositories/customers";

defineProps<{
  matches: CustomerMatch[];
  errors: { fullName: string | null; phone: string | null };
  /** Whether a save was attempted, which shows the errors. */
  submitted: boolean;
}>();

const searchInput = defineModel<string>("searchInput", { required: true });
const selected = defineModel<CustomerMatch | null>("selected", { required: true });
const newOwner = defineModel<{ fullName: string; phone: string; email: string }>("newOwner", { required: true });
</script>
