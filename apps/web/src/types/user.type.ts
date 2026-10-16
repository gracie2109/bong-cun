import type { IROLE } from ".";
import type { IAddress } from "./location.type";

interface BasicInfo {
  phoneNumber?: string;
  photoURL?: string;
  email: string;
  displayName: string;
}

export const initAddress: IAddress = {
  address: "",
  ward: { WardName: "", WardCode: 0 },
  district: { DistrictName: "", DistrictID: 0 },
  province: { ProvinceName: "", ProvinceID: 0 },
};

interface IShipping {
  available_id: string | null;
  isActive: boolean;
  province: IAddress
}

interface ProvideData extends BasicInfo {
  providerId: string;
}

export interface IUser extends BasicInfo, IShipping {
  userId: string;
  password: string;
  role?: IROLE;
  gender?:string,
  userName: string;
  fullName?: string;
  updatedAt?: Date | string;
  createdAt?: Date | string;
  providerData?: ProvideData[];
  [key: string]: any;
  confirm?: string;
  shipping_address: ProvideData;
  groupIds: null | any[];
}

export type IRegisterPayload = Pick<
  IUser,
  "email" | "displayName" | "password" | "confirm"
>;

export type ILoginPayload = Pick<IUser, "email" | "password">;
