import { useMutation } from "@tanstack/vue-query";
import { toast } from "vue-sonner";
import { supabase } from "@/plugins/supabase";
import { createBooking, type BookingInput } from "@/repositories/bookings";

export const useCreateBooking = () =>
  useMutation({
    mutationFn: (input: BookingInput) => createBooking(supabase, input),
    onSuccess: () => toast.success("Order Service success!"),
    onError: () => toast.error("Order Service fail!"),
  });
