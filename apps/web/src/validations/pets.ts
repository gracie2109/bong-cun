import * as z from "zod";
import { validCanNull, validMinString } from ".";

export const PetsValid = z.object({
  name: validMinString("name", 3),
  icon: z.any(),
  desc: validMinString("desc", 3),
});

export const PetsServicesValid = z.object({
  name: validMinString("name", 3),
  desc: validCanNull("desc"),
  petIds: z.any(),
  petsProfiles: z.any(),
  type: z.any(),
  unit: validCanNull("unit"),
  generalPrice: validCanNull("generalPrice"),
});
