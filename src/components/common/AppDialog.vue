<template>
  <Dialog :open="open" @update:open="onOpenChange">
    <DialogContent
      :class="cn('gap-0 p-0', SIZE_CLASS[size], contentClass)"
      @open-auto-focus="focusFirstField"
      @escape-key-down="keepOpenWhenBusy"
      @pointer-down-outside="keepOpenWhenBusyOrPersistent"
      @interact-outside="keepOpenWhenBusyOrPersistent"
    >
      <!-- display: contents keeps the grid layout; the wrapper only exists to catch Enter -->
      <div class="contents" @keydown.enter="onEnter">
        <DialogHeader :class="cn('space-y-1 px-6 py-4 pr-12 text-left', $slots.default && 'border-b', hideHeader && 'sr-only')">
          <DialogTitle>
            <slot name="title">{{ title }}</slot>
          </DialogTitle>
          <DialogDescription :class="!description && !$slots.description && 'sr-only'">
            <slot name="description">{{ description ?? title }}</slot>
          </DialogDescription>
        </DialogHeader>

        <div v-if="$slots.default" :class="cn('max-h-[70dvh] overflow-y-auto px-6 py-4', bodyClass)">
          <slot />
        </div>

        <DialogFooter v-if="!hideFooter" :class="cn('gap-2 px-6 py-3', $slots.default && 'border-t')">
          <slot name="footer" :ok="ok" :cancel="cancel" :busy="busy">
            <Button v-if="!hideCancel" type="button" variant="outline" :disabled="busy" @click="cancel">
              {{ cancelText ?? $t("common.cancel") }}
            </Button>
            <Button
              :type="formId ? 'submit' : 'button'"
              :form="formId"
              :variant="danger ? 'destructive' : 'default'"
              data-dialog-ok
              :disabled="okDisabled || busy"
              @click="!formId && ok()"
            >
              <Loader2 v-if="busy" class="mr-2 size-4 animate-spin" />
              {{ okText ?? $t("common.ok") }}
            </Button>
          </slot>
        </DialogFooter>
      </div>
    </DialogContent>
  </Dialog>
</template>

<script lang="ts" setup>
import { nextTick } from "vue";
import { Loader2 } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { cn } from "@/lib/utils";

type Size = "sm" | "md" | "lg" | "xl";

const SIZE_CLASS: Record<Size, string> = {
  sm: "sm:max-w-sm",
  md: "sm:max-w-md",
  lg: "sm:max-w-lg",
  xl: "sm:max-w-2xl",
};

/** Controls that handle the Enter key themselves; a dialog never takes it from them. */
const OWN_ENTER = 'textarea, select, button, a[href], [role="combobox"], [role="listbox"], [role="option"], [role="menuitem"], [contenteditable="true"], form';

/**
 * One dialog for every pop-up: a title bar with a close button at the top right, a scrolling
 * body, and an OK / Cancel footer. Esc closes it, Enter presses OK, and while `busy` it cannot be
 * dismissed. Put a form in the body and pass its id as `formId` and OK submits that form instead.
 */
const props = withDefaults(
  defineProps<{
    title: string;
    description?: string;
    size?: Size;
    okText?: string;
    cancelText?: string;
    /** OK is greyed out and Enter does nothing. */
    okDisabled?: boolean;
    /** Work is running: OK shows a spinner and nothing can close the dialog. */
    busy?: boolean;
    /** A red OK button, for deleting or cancelling something. */
    danger?: boolean;
    hideCancel?: boolean;
    hideFooter?: boolean;
    /** Keep the title for screen readers only, when the body brings its own heading. */
    hideHeader?: boolean;
    /** A click outside the dialog does not close it. */
    persistent?: boolean;
    /** `id` of a `<form>` in the body: OK becomes its submit button. */
    formId?: string;
    contentClass?: string;
    bodyClass?: string;
  }>(),
  { size: "md" }
);

const open = defineModel<boolean>("open", { required: true });

const emit = defineEmits<{
  /** OK was pressed (or Enter), when there is no `formId`. */
  ok: [];
  /** The dialog was dismissed: the close button, Cancel, Esc or a click outside. */
  cancel: [];
}>();

const ok = () => {
  if (props.okDisabled || props.busy) return;
  emit("ok");
};

const cancel = () => {
  if (props.busy) return;
  open.value = false;
  emit("cancel");
};

const onOpenChange = (value: boolean) => {
  if (value) {
    open.value = true;
    return;
  }
  cancel();
};

const keepOpenWhenBusy = (event: Event) => {
  if (props.busy) event.preventDefault();
};

const keepOpenWhenBusyOrPersistent = (event: Event) => {
  if (props.busy || props.persistent) event.preventDefault();
};

const onEnter = (event: KeyboardEvent) => {
  const target = event.target as HTMLElement;
  if (event.isComposing || event.defaultPrevented || event.shiftKey || target.closest(OWN_ENTER)) return;
  event.preventDefault();
  if (props.formId) {
    (document.getElementById(props.formId) as HTMLFormElement | null)?.requestSubmit();
    return;
  }
  ok();
};

// Start on the first field so typing works at once; with no field, on OK so Enter confirms.
const focusFirstField = (event: Event) => {
  event.preventDefault();
  const content = event.target as HTMLElement;
  void nextTick(() => {
    const field = content.querySelector<HTMLElement>("input:not([disabled]), textarea:not([disabled]), select:not([disabled])");
    const okButton = content.querySelector<HTMLElement>("[data-dialog-ok]");
    (field ?? okButton)?.focus();
  });
};
</script>
