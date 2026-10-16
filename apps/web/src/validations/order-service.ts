import * as z from 'zod';

import { validMinString, validPhoneNumber } from "."

export const orderServiceSchema = z.object({
    name: validMinString("name", 3),
    phoneNumber: validPhoneNumber,
    petNum: z.any(),
    services: z.array(z.object({
        id: z.string(),
        name: z.string(),
        price: z.any(),
        duration: z.any(),
        type: z.string()
    })).min(1, {
        message: "You need choose at least 1 service or combo"
    }),
    time: z.any(),

})