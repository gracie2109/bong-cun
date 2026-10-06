// GHN is called through our server routes (server/api/ghn), which hold the
// token, the ShopId and the service id.
type GhnResponse<T> = { code?: number; message?: string; data?: T };

// The payload is not forwarded yet: the server route still sends fixed test data.
export async function calcShippingFee(_payload?: unknown) {
  try {
    const response = await $fetch<GhnResponse<any>>("/api/ghn/shipping-fee", {
      method: "POST",
    });
    if (response) {
      if (response.code !== 200) {
        console.log("calcShippingFee fail", response?.message);
      }
      return response.data;
    }
  } catch (err: any) {
    console.log(new Error(err));
  }
}

// Tính thời gian dự kiến giao
export async function getLeadTime() {
  try {
    const response = await $fetch<GhnResponse<any>>("/api/ghn/leadtime", {
      method: "POST",
    });

    if (response) {
      if (response.code !== 200) {
        console.log("getLeadTime fail", response?.message);
      }
      return response.data?.leadtime;
    }
  } catch (err: any) {
    console.log("getLeadTime fail", err?.message);
  }
}
