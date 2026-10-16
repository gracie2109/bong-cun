import * as z from 'zod';
import { validMinString } from '.';

enum LoginMethod {
    GOOGLE = 'Google',
    PHONE = 'Phone number',
    EMAIL = 'Email'
}
enum EnableOrDisable {
    DISABLE = 'Disable',
    ENABLE = 'Enable'
}
export const StoreSchema = z.object({
    name: validMinString('name', 3),
    description: validMinString('description', 3),
    logo: z.any(),
    favicon: z.any(),
    infomation: z.object({
        address: z.array(
            z.object({
                provide: z.string(),
                ward: z.string(),
                address: z.string(),
                district: z.string(),
                map_url: z.string(),
            })
        ),
        socials: z.array(
            z.object({
                name: z.string(),
                url: z.string(),
                status: z.nativeEnum(EnableOrDisable)
            })
        )
    }),
    settings:z.object({
        loginMethod: z.nativeEnum(LoginMethod)
    })
})  