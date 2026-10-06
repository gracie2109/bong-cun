import * as z from 'zod';
import { OTP_CODE_PATTERN } from "@/config/auth";
import { ConfirmPassSchema, EmailSChema, passWordCheck, validEmail, validMinString } from "."



export const loginSchema = z.object({
    email: validEmail,
    password: validMinString('password', 4),
})


export const registerSchema = z
    .object({
        displayName: z.string().min(3, {
            message: "Name must be at least 5 characters.",
        }),
        email: validEmail,
    })
    .merge(ConfirmPassSchema)
    .superRefine(passWordCheck);

export const resetPasswordWithCodeSchema = z
    .object({
        code: z.string().regex(OTP_CODE_PATTERN, { message: "Enter the numeric code from your email" }),
    })
    .merge(ConfirmPassSchema)
    .superRefine(passWordCheck);
