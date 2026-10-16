import * as z from 'zod'
import {validMinString, validCanNull} from "."
import i18n from "@/i18n"

const t = i18n.global.t
export const productFormSchema = z.object({
    name: validMinString(() => t('pageFields.products.name'), 3),
    description: validCanNull('description'),
})

export type InferProductFormInfo = z.infer<typeof productFormSchema>