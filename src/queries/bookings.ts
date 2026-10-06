import { useMutation } from "@tanstack/vue-query";
import { toast } from "vue-sonner";
import { supabaseClient } from "@/lib/supabase";
import { createBooking, type BookingInput } from "@/repositories/bookings";

export const useCreateBooking = () =>
  useMutation({
    mutationFn: (input: BookingInput) => createBooking(supabaseClient(), input),
    onSuccess: () => toast.success("Order Service success!"),
    onError: () => toast.error("Order Service fail!"),
  });
