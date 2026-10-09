<template>
  <div class="space-y-5">
    <div class="flex items-center gap-4">
      <UploadFields
        :folder-name="'users'"
        :limit="1"
        :show-control="false"
        @set-images="(images: any[]) => form.setFieldValue('images', images)"
      />
      <div>
        <p class="text-sm font-semibold">{{ $t("pageFields.customers.form.avatarTitle") }}</p>
        <p class="text-xs text-muted-foreground">{{ $t("pageFields.customers.form.avatarHint") }}</p>
      </div>
    </div>

    <div class="grid gap-4 sm:grid-cols-2">
      <FormField v-slot="{ componentField }" name="fullName" :rules="required">
        <FormItem>
          <FormLabel>{{ $t("pageFields.customers.form.fullName") }} *</FormLabel>
          <FormControl><Input v-bind="componentField" :placeholder="$t('pageFields.customers.form.fullNamePh')" /></FormControl>
          <FormMessage />
        </FormItem>
      </FormField>
      <FormField v-slot="{ componentField }" name="displayName" :rules="required">
        <FormItem>
          <FormLabel>{{ $t("pageFields.customers.form.displayName") }} *</FormLabel>
          <FormControl><Input v-bind="componentField" :placeholder="$t('pageFields.customers.form.displayNamePh')" /></FormControl>
          <FormMessage />
        </FormItem>
      </FormField>
    </div>

    <FormField v-slot="{ value, handleChange }" name="gender">
      <FormItem>
        <FormLabel>{{ $t("pageFields.customers.form.gender") }}</FormLabel>
        <div class="grid grid-cols-3 gap-1 rounded-lg bg-muted p-1">
          <button
            v-for="g in BASE_GENDER"
            :key="g.value"
            type="button"
            class="rounded-md py-1.5 text-sm font-medium transition-colors"
            :class="value === g.value ? 'bg-white text-primary shadow-sm' : 'text-muted-foreground'"
            @click="handleChange(g.value)"
          >
            {{ (g.name as Record<string, string>)[String(locale)] }}
          </button>
        </div>
      </FormItem>
    </FormField>

    <div class="grid gap-4 sm:grid-cols-2">
      <FormField v-slot="{ componentField }" name="phoneNumber" :rules="phoneRule">
        <FormItem>
          <FormLabel>{{ $t("pageFields.customers.form.phone") }} *</FormLabel>
          <FormControl>
            <div class="flex">
              <span class="grid place-items-center rounded-l-md border border-r-0 bg-muted px-3 text-sm text-muted-foreground">
                {{ PHONE_PREFIX }}
              </span>
              <Input
                v-bind="componentField"
                class="rounded-l-none"
                inputmode="tel"
                :placeholder="$t('pageFields.customers.form.phonePh')"
              />
            </div>
          </FormControl>
          <FormMessage />
        </FormItem>
      </FormField>
      <FormField v-slot="{ componentField }" name="email" :rules="emailRule">
        <FormItem>
          <FormLabel>{{ $t("pageFields.customers.form.email") }} *</FormLabel>
          <FormControl><Input v-bind="componentField" :placeholder="$t('pageFields.customers.form.emailPh')" type="email" /></FormControl>
          <FormMessage />
        </FormItem>
      </FormField>
    </div>

    <CustomerPasswordSection :form="form" />
  </div>
</template>

<script lang="ts" setup>
import { useI18n } from "vue-i18n";
import type { FormContext } from "vee-validate";
import { UploadFields } from "@/components/common/";
import { FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { BASE_GENDER } from "@/lib/constants";
import type { IUser } from "@/types/user.type";
import { useCustomerRules } from "./customerFormRules";
import CustomerPasswordSection from "./CustomerPasswordSection.vue";

const PHONE_PREFIX = "+84";

defineProps<{ form: FormContext<IUser> }>();

const { locale } = useI18n();
const { required, emailRule, phoneRule } = useCustomerRules();
</script>
