<template>
  <div class="mx-auto w-full max-w-3xl space-y-4 pb-10">
    <div class="flex items-center justify-between gap-3">
      <div class="flex gap-1.5">
        <button
          v-for="item in APPOINTMENT_SCOPES"
          :key="item"
          type="button"
          class="rounded-full border px-3 py-1 text-sm font-medium transition"
          :class="item === page.scope.value ? 'border-primary bg-primary text-white' : 'hover:border-primary/50'"
          @click="page.scope.value = item"
        >
          {{ $t(`client.appointments.scope.${item}`) }}
        </button>
      </div>
      <Button as-child size="sm">
        <RouterLink :to="{ name: 'spa-book' }">
          <CalendarPlus class="mr-1 size-4" />
          {{ $t("client.spa.book") }}
        </RouterLink>
      </Button>
    </div>

    <p v-if="page.loading.value" class="py-12 text-center text-muted-foreground">{{ $t("petCare.common.loading") }}</p>
    <div v-else-if="page.failed.value" class="py-12 text-center">
      <p class="mb-3 text-muted-foreground">{{ $t("client.appointments.loadFailed") }}</p>
      <Button variant="outline" @click="page.retry">{{ $t("client.catalog.retry") }}</Button>
    </div>
    <div v-else-if="page.rows.value.length === 0" class="rounded-xl border border-dashed py-12 text-center text-muted-foreground">
      {{ $t(`client.appointments.empty.${page.scope.value}`) }}
    </div>
    <template v-else>
      <ul class="space-y-3" :class="page.fetching.value && 'opacity-60'">
        <AppointmentCard
          v-for="appointment in page.rows.value"
          :key="appointment.id"
          :appointment="appointment"
          :busy="page.cancelling.value"
          @cancel="page.toCancel.value = appointment"
        />
      </ul>
      <div class="flex items-center justify-between text-sm text-muted-foreground">
        <span>
          {{
            $t("common.table.range", {
              from: (page.page.value - 1) * page.pageSize + 1,
              to: (page.page.value - 1) * page.pageSize + page.rows.value.length,
              total: page.total.value,
            })
          }}
        </span>
        <TablePager v-model:page="page.page.value" :page-count="page.pageCount.value" :loading="page.fetching.value" />
      </div>
    </template>

    <DialogConfirm
      :open="page.toCancel.value !== null"
      danger
      :title="$t('client.appointments.cancelTitle')"
      :desc="$t('client.appointments.cancelDesc', { code: page.toCancel.value?.code ?? '' })"
      :ok-btn="$t('client.appointments.cancel')"
      @handle-ok="page.confirmCancel"
      @open-change="page.toCancel.value = null"
      @cancel="page.toCancel.value = null"
    />
  </div>
</template>

<script lang="ts" setup>
import { CalendarPlus } from "lucide-vue-next";
import { DialogConfirm } from "@/components/common";
import TablePager from "@/components/common/TablePager.vue";
import { Button } from "@/components/ui/button";
import { useMyAppointments } from "@/composables/account/useMyAppointments";
import { APPOINTMENT_SCOPES } from "@/types/account";
import AppointmentCard from "./components/AppointmentCard.vue";

const page = useMyAppointments();
</script>
