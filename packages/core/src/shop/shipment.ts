interface ShareShipmentAddress {
    districtId: string,
    wardCode:number
}

export interface IGHNShippingPayload {
    shippingInfo: ShareShipmentAddress,
    storeInfo: ShareShipmentAddress,
    orderInfo:{
        height:number,
        length:number,
        weight:number,
        width: number,
        insurance_value:number
    }
}