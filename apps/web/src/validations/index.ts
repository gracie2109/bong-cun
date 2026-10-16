import * as z from 'zod';

import i18n from "@/i18n"

const t = i18n.global.t;
// The message is translated when validation runs, not when the schema is built:
// page modules are evaluated before @nuxtjs/i18n has finished setting up. Pass
// `name` as a function when it needs translating too.
export const validMinString = (name: string | (() => string), min: number) => z
    .string({
        errorMap: (issue, ctx) => issue.code === z.ZodIssueCode.too_small
            ? { message: t('validation.min', { name: typeof name === 'function' ? name() : name, min: min }) }
            : { message: ctx.defaultError },
    })
    .min(min);
export const validaMaxString = (name: string, min: number, max: number) => z.string().max(max, { message: `${name} must be at least ${max} characters` });
export const validMinMaxString = (name: string, min: number, max: number) =>
    z.string()
        .max(max, { message: `${name} must be at least ${max} characters` })
        .min(min, { message: `${name} must be at least ${min} characters` })

export const validCanNull = (name: string) => z.any().optional().transform(value => value || null)
export const arrayNeedAtLeastOne = (name: string) => z.array(z.any()).refine(value => value.some(item => item), {
    message: `${name} need to have at least one item.`,
})


export const ConfirmPassSchema = z.object({
    password: z
        .string()
        .regex(
            /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$/,
            "Password must contain at least one uppercase letter, one lowercase letter, one digit, and be at least 8 characters long"
        ),
    confirm: z.string(),
});
export const passWordCheck = (v: any, ctx: any) => {
    if (v.password !== v.confirm) {
        ctx.addIssue({
            code: "custom",
            message: "Passwords do not match",
            path: ["confirm"],
        });
    }
};

const emailRegex =
    /^(?!\.)(?!.*\.\.)([A-Z0-9_'+-\.]*)[A-Z0-9_'+-]@([A-Z0-9][A-Z0-9\-]*\.)+[A-Z]{2,}$/i;

export const validEmail = z.string().superRefine((data, ctx) => {
    if (!emailRegex.test(data)) {
        ctx.addIssue({
            code: z.ZodIssueCode.invalid_string,
            message: "Invalid email address",
            validation: "email",
        });
    }
});

export const EmailSChema = z.object({
    email: validEmail,
});

const isVietnamesePhoneNumber = /^(03|05|07|08|09|01[2|6|8|9])+([0-9]{8})$/;

export const validPhoneNumber = z.string().superRefine((data, ctx) => {
    if (!isVietnamesePhoneNumber.test(data)) {
        ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: "Invalid phone number",
        });
        return z.NEVER;

    }
});
