import * as z from 'zod';
import { validMinString } from '.';

export const ServiceProvider = z.object({
    name: validMinString('name', 3),
    desc: validMinString('desc', 3),
    phone: validMinString('phone', 10),
   
})  