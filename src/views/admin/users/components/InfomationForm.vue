<template>
  <form class="flex h-full min-h-0 flex-col" @submit.prevent="submitHandle">
    <header class="space-y-1 border-b px-6 py-5">
      <div class="flex items-center gap-2">
        <h2 class="text-xl font-bold">{{ $t("pageFields.customers.form.title") }}</h2>
        <span class="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-semibold text-primary">
          {{ $t("pageFields.customers.form.new") }}
        </span>
      </div>
      <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.form.subtitle") }}</p>
    </header>

    <Tabs :model-value="step" class="flex min-h-0 flex-1 flex-col" @update:model-value="goTo">
      <TabsList class="h-11 w-full justify-start gap-4 rounded-none border-b bg-transparent p-0 px-6">
        <TabsTrigger
          v-for="(s, i) in STEPS"
          :key="s.id"
          :value="s.id"
          class="h-full rounded-none border-b-2 border-transparent px-1 text-muted-foreground data-[state=active]:border-primary data-[state=active]:text-primary"
        >
          <span class="flex items-center gap-1.5 whitespace-nowrap">
            <Check v-if="i < stepIndex" class="size-3.5 text-green-600" />
            <component :is="s.icon" v-else class="size-3.5" />
            {{ i + 1 }}. {{ $t(`pageFields.customers.form.step.${s.id}`) }}
            <span
              v-if="s.id === 'address' && addressHasError"
              class="size-2 rounded-full bg-destructive"
            />
          </span>
        </TabsTrigger>
      </TabsList>

      <div class="min-h-0 flex-1 overflow-y-auto px-6 py-5">
        <TabsContent :value="STEP.INFO" force-mount :hidden="step !== STEP.INFO" class="mt-0 space-y-5">
          <div class="flex items-center gap-4">
            <UploadFields
              :folder-name="'users'"
              :limit="1"
              :show-control="false"
              @set-images="setImages"
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

          <section class="space-y-3 rounded-xl border bg-muted/30 p-4">
            <div class="flex items-center justify-between">
              <h3 class="flex items-center gap-2 text-sm font-semibold">
                <LockKeyhole class="size-4 text-primary" />
                {{ $t("pageFields.customers.form.passwordTitle") }}
              </h3>
              <button
                type="button"
                class="flex items-center gap-1 text-xs font-semibold text-primary hover:underline"
                @click="generatePassword"
              >
                <RefreshCw class="size-3" />
                {{ $t("pageFields.customers.form.generate") }}
              </button>
            </div>
            <FormField v-slot="{ componentField }" name="password" :rules="passwordRule">
              <FormItem>
                <FormControl>
                  <div class="relative">
                    <Input
                      v-bind="componentField"
                      :type="showPassword ? 'text' : 'password'"
                      class="pr-10 font-mono"
                      :placeholder="$t('pageFields.customers.form.passwordPh')"
                      autocomplete="new-password"
                    />
                    <button
                      type="button"
                      class="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
                      @click="showPassword = !showPassword"
                    >
                      <EyeOff v-if="showPassword" class="size-4" />
                      <Eye v-else class="size-4" />
                    </button>
                  </div>
                </FormControl>
                <FormMessage />
              </FormItem>
            </FormField>
            <div class="flex items-center gap-3">
              <div class="grid flex-1 grid-cols-4 gap-1">
                <span
                  v-for="n in STRENGTH_LEVELS"
                  :key="n"
                  class="h-1.5 rounded-full"
                  :class="n <= strength ? STRENGTH_COLORS[strength - 1] : 'bg-muted'"
                />
              </div>
              <span v-if="strength" class="text-xs font-medium text-muted-foreground">
                {{ $t(`pageFields.customers.form.strength.${STRENGTH_KEYS[strength - 1]}`) }}
              </span>
            </div>
            <p class="flex items-start gap-2 text-xs text-muted-foreground">
              <Info class="mt-0.5 size-3.5 shrink-0" />
              {{ $t("pageFields.customers.form.passwordHint") }}
            </p>
          </section>
        </TabsContent>

        <TabsContent :value="STEP.GROUPS" force-mount :hidden="step !== STEP.GROUPS" class="mt-0 space-y-4">
          <div>
            <h3 class="font-semibold">{{ $t("pageFields.customers.form.groupsTitle") }}</h3>
            <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.form.groupsDesc") }}</p>
          </div>
          <Multiselect
            v-model="groups"
            :options="props.listUserGroup"
            :multiple="true"
            :close-on-select="false"
            :clear-on-select="false"
            :preserve-search="true"
            :placeholder="$t('pageFields.customers.form.groupsPlaceholder')"
            label="name"
            track-by="name"
            @update:model-value="onGroupsChange"
          />
          <p
            v-if="!props.listUserGroup.length"
            class="rounded-lg border border-dashed p-4 text-center text-sm text-muted-foreground"
          >
            {{ $t("pageFields.customers.form.groupsEmpty") }}
          </p>
        </TabsContent>

        <TabsContent :value="STEP.ADDRESS" force-mount :hidden="step !== STEP.ADDRESS" class="mt-0 space-y-4">
          <div>
            <h3 class="flex items-center gap-2 font-semibold">
              <Truck class="size-4 text-primary" />
              {{ $t("pageFields.customers.form.addressTitle") }}
            </h3>
            <p class="text-sm text-muted-foreground">{{ $t("pageFields.customers.form.addressDesc") }}</p>
          </div>
          <ProvinceAddress :address-model="props.addressModel" :form="props.form" field-name="province" />
        </TabsContent>
      </div>
    </Tabs>

    <footer class="flex items-center justify-between gap-3 border-t px-6 py-4">
      <Button type="button" variant="ghost" :disabled="props.loading" @click="emit('closeDialog')">
        {{ $t("pageFields.customers.form.cancel") }}
      </Button>
      <div class="flex gap-2">
        <Button v-if="stepIndex > 0" type="button" variant="outline" @click="goBack">
          <ArrowLeft class="mr-1 size-4" />
          {{ $t("pageFields.customers.form.back") }}
        </Button>
        <Button v-if="!isLastStep" type="button" @click="goNext">
          {{ $t("pageFields.customers.form.next") }}
          <ArrowRight class="ml-1 size-4" />
        </Button>
        <Button v-else type="submit" :disabled="props.loading">
          <Loader2 v-if="props.loading" class="mr-2 size-4 animate-spin" />
          {{ $t(props.loading ? "pageFields.customers.form.saving" : "pageFields.customers.form.save") }}
        </Button>
      </div>
    </footer>
  </form>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import type { FormContext } from "vee-validate";
import Multiselect from "vue-multiselect";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Eye,
  EyeOff,
  Info,
  Loader2,
  LockKeyhole,
  MapPin,
  RefreshCw,
  Truck,
  User,
  Users,
} from "lucide-vue-next";
import { FormControl, FormItem, FormLabel, FormMessage, FormField } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { UploadFields, ProvinceAddress } from "@/components/common/";
import { BASE_GENDER } from "@/lib/constants";
import type { IAddress } from "@/types/location.type";
import type { IUser } from "@/types/user.type";

const STEP = { INFO: "info", GROUPS: "groups", ADDRESS: "address" } as const;
type Step = (typeof STEP)[keyof typeof STEP];

const STEPS = [
  { id: STEP.INFO, icon: User },
  { id: STEP.GROUPS, icon: Users },
  { id: STEP.ADDRESS, icon: MapPin },
];
const INFO_FIELDS = ["fullName", "displayName", "phoneNumber", "email", "password"] as const;

const PHONE_PREFIX = "+84";
const PHONE_PATTERN = /^0?\d{9}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PASSWORD_MIN_LENGTH = 8;
const GENERATED_PASSWORD_LENGTH = 12;
const PASSWORD_CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$";
const STRENGTH_LEVELS = [1, 2, 3, 4];
const STRENGTH_KEYS = ["weak", "medium", "strong", "veryStrong"];
const STRENGTH_COLORS = ["bg-red-500", "bg-amber-500", "bg-lime-500", "bg-green-500"];

const props = defineProps<{
  form: FormContext<IUser>;
  loading: boolean;
  listUserGroup: any[];
  addressModel: IAddress;
}>();
const emit = defineEmits(["onSubmit", "closeDialog"]);

const { locale, t } = useI18n();

const step = ref<Step>(STEP.INFO);
const stepIndex = computed(() => STEPS.findIndex((s) => s.id === step.value));
const isLastStep = computed(() => stepIndex.value === STEPS.length - 1);
const showPassword = ref(false);
const groups = ref([]);

const required = (v: unknown) => (v ? true : t("pageFields.customers.form.required"));
const emailRule = (v: string) =>
  !v ? t("pageFields.customers.form.required") : EMAIL_PATTERN.test(v) || t("pageFields.customers.form.invalidEmail");
const phoneRule = (v: string) =>
  !v
    ? t("pageFields.customers.form.required")
    : PHONE_PATTERN.test(v.replace(/\s/g, "")) || t("pageFields.customers.form.invalidPhone");
const passwordRule = (v: string) =>
  (v ?? "").length >= PASSWORD_MIN_LENGTH ||
  t("pageFields.customers.form.passwordMin", { min: PASSWORD_MIN_LENGTH });

const strength = computed(() => {
  const pw = String(props.form.values.password ?? "");
  if (!pw) return 0;
  const score = [pw.length >= PASSWORD_MIN_LENGTH, /[A-Z]/.test(pw) && /[a-z]/.test(pw), /\d/.test(pw), /[^A-Za-z0-9]/.test(pw)];
  return Math.max(1, score.filter(Boolean).length);
});

const addressHasError = computed(() => Boolean(props.form.errors.value.province));

const generatePassword = () => {
  const bytes = crypto.getRandomValues(new Uint32Array(GENERATED_PASSWORD_LENGTH));
  const password = Array.from(bytes, (b) => PASSWORD_CHARSET[b % PASSWORD_CHARSET.length]).join("");
  props.form.setFieldValue("password", password);
  showPassword.value = true;
};

const validateInfo = async () => {
  const results = await Promise.all(INFO_FIELDS.map((f) => props.form.validateField(f)));
  return results.every((r) => r.valid);
};

const goTo = async (next: unknown) => {
  const target = next as Step;
  const targetIndex = STEPS.findIndex((s) => s.id === target);
  if (targetIndex > 0 && stepIndex.value === 0 && !(await validateInfo())) return;
  step.value = target;
};
const goNext = () => goTo(STEPS[stepIndex.value + 1].id);
const goBack = () => (step.value = STEPS[stepIndex.value - 1].id);

const setImages = (images: any[]) => props.form.setFieldValue("images", images);

const onGroupsChange = (value: any[] | null) => {
  props.form.setFieldValue("groupIds", value?.map((i) => i.id) ?? null);
  props.form.setFieldValue("groupProfile", value ?? []);
};

const submitHandle = async () => {
  if (!(await validateInfo())) {
    step.value = STEP.INFO;
    return;
  }
  emit("onSubmit");
};
</script>
