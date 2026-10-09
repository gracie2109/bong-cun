import { useI18n } from "vue-i18n";

export const PASSWORD_MIN_LENGTH = 8;

const PHONE_PATTERN = /^0?\d{9}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const GENERATED_PASSWORD_LENGTH = 12;
/** Without look-alike characters (0/O, 1/l/I), so a generated password can be read out. */
const PASSWORD_CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$";

/** Validation rules of the customer form; each returns true or the message to show. */
export const useCustomerRules = () => {
  const { t } = useI18n();

  const required = (value: unknown) => (value ? true : t("pageFields.customers.form.required"));
  const emailRule = (value: unknown) =>
    !value
      ? t("pageFields.customers.form.required")
      : EMAIL_PATTERN.test(String(value)) || t("pageFields.customers.form.invalidEmail");
  const phoneRule = (value: unknown) =>
    !value
      ? t("pageFields.customers.form.required")
      : PHONE_PATTERN.test(String(value).replace(/\s/g, "")) || t("pageFields.customers.form.invalidPhone");
  const passwordRule = (value: unknown) =>
    String(value ?? "").length >= PASSWORD_MIN_LENGTH ||
    t("pageFields.customers.form.passwordMin", { min: PASSWORD_MIN_LENGTH });

  return { required, emailRule, phoneRule, passwordRule };
};

/** 0 for an empty password, otherwise 1 (weak) to 4 (very strong). */
export const passwordStrength = (password: string): number => {
  if (!password) return 0;
  const score = [
    password.length >= PASSWORD_MIN_LENGTH,
    /[A-Z]/.test(password) && /[a-z]/.test(password),
    /\d/.test(password),
    /[^A-Za-z0-9]/.test(password),
  ];
  return Math.max(1, score.filter(Boolean).length);
};

export const generatePassword = (): string => {
  const bytes = crypto.getRandomValues(new Uint32Array(GENERATED_PASSWORD_LENGTH));
  return Array.from(bytes, (b) => PASSWORD_CHARSET[b % PASSWORD_CHARSET.length]).join("");
};
