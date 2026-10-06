<script lang="ts" setup>
import { ref } from "vue";

import { FormControl, FormField, FormItem } from "@/components/ui/form";
import VueDatePicker, { type DatePickerInstance } from "@vuepic/vue-datepicker";
import { REGISTER_PARAMS, registerFormSchema } from "@/validations/register";
import useValidation from "@/composables/useValidation";
import { useCreateBooking } from "@/queries/bookings";
import FormItemInline from "@/components/FormFieldInline.vue";

const formSchema = ref<any>({
  name: "",
  time: new Date(),
  phone_number: "",
  email: "",
  content: "",
});
const createBooking = useCreateBooking();
const datepicker = ref<DatePickerInstance>(null);

const { validate, isValid, getError, isInValid, scrolltoError } = useValidation(
  registerFormSchema,
  formSchema,
  {
    mode: "lazy",
  }
);

async function handleSubmit() {
  await validate();

  if (isValid.value) {
    // `time` is sent as a real timestamp; the old "MM/dd/yyyy hh:mm:ss" string
    // was 12-hour with no AM/PM, so it could not be read back unambiguously.
    createBooking.mutate(formSchema.value, {
      onSuccess: () => {
        formSchema.value = {
          name: "",
          time: new Date(),
          phone_number: "",
          email: "",
          content: "",
        };
        if (datepicker.value) {
          datepicker.value.clearValue();
        }
      },
    });
  } else {
    scrolltoError(".p-invalid", { offset: 24 });
  }
}
</script>

<template>
  <div id="register-form">
    <div class="wrap-form" id="dat_lich">
      <div class="head-w">
        <div class="container-custom">
          <div class="wrap-content">
            <div class="title-form">
              <span class="font-semibold text-primary pl-16"
                >Bạn có muốn ghé Annie ?</span
              >
              <p>Đặt lịch ngay cho Boss nào!</p>
            </div>
            <div class="box-form2">
              <div
                class="box-form lg:p-[105px 115px 80px] md:p-[105px 115px 80px] p-20"
              >
                <div class="title-form2">
                  <span class="font-semibold">Đặt lịch ngay</span>
                </div>
                <form @submit.prevent="handleSubmit">
                  <div class="grid md:grid-cols-2 gap-8 sm:grid-cols-1">
                    <FormItemInline
                      :name="REGISTER_PARAMS.NAME"
                      placeholder="Họ và tên (*)"
                      :error="getError(REGISTER_PARAMS.NAME)"
                      :isInValid="!!getError(REGISTER_PARAMS.NAME)"
                      v-model="formSchema.name"
                    />
                    <FormItemInline
                      :name="REGISTER_PARAMS.PHONE_NUMBER"
                      placeholder="Số điện thoại (*)"
                      :error="getError(REGISTER_PARAMS.PHONE_NUMBER)"
                      :isInValid="!!getError(REGISTER_PARAMS.PHONE_NUMBER)"
                      v-model="formSchema.phone_number"
                    />
                    <FormItemInline
                      :name="REGISTER_PARAMS.EMAIL"
                      placeholder="Địa chỉ email (*)"
                      :error="getError(REGISTER_PARAMS.EMAIL)"
                      :isInValid="!!getError(REGISTER_PARAMS.EMAIL)"
                      v-model="formSchema.email"
                    />

                    <FormField
                      v-slot="{ componentField }"
                      :name="REGISTER_PARAMS.TIME"
                    >
                      <FormItem>
                        <FormControl>
                          <div class="pt-3 w-full">
                            <VueDatePicker
                              ref="datepicker"
                              class="custom-datepicker"
                              id="date-picker-cs"
                              v-model="formSchema.time"
                              v-bind="componentField"
                              placeholder="Chọn thời gian"
                              teleport-center
                              :start-date="new Date()"
                              :enable-time-picker="true"
                              auto-apply
                              :min-date="new Date()"
                              :start-time="{
                                hours: new Date().getHours() + 1,
                                minutes: new Date().getMinutes(),
                              }"
                              :max-time="{
                                hours: 23,
                                minutes: 0,
                              }"
                            />
                          </div>
                        </FormControl>
                      </FormItem>
                    </FormField>
                  </div>
                  <div class="w-full my-8">
                    <FormField
                      v-slot="{ componentField }"
                      :name="REGISTER_PARAMS.CONTENT"
                    >
                      <FormItem>
                        <FormControl>
                          <textarea
                            class="textarea text-sm"
                            placeholder="Lời nhắn"
                            v-bind="componentField"
                            v-model="formSchema.content"
                          />
                        </FormControl>
                      </FormItem>
                    </FormField>
                  </div>
                  <div class="w-full text-center mt-6">
                    <button type="submit" class="btn-sub btn-readmore">
                      Gửi ngay <i class="fa-regular fa-arrow-right-long"></i>
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
#register-form {
  font-family: "Quicksand", sans-serif !important;
}
:deep(.dp__input_wrap) {
  width: 100% !important;
  font-size: 0.875rem !important;
  line-height: 1.25rem !important;
  color: #582e15 !important;
  z-index: 999 !important;
}
:deep(.dp__input) {
  border: none !important;
  border-bottom: 1px solid #e3c2af !important;
  outline: none;
  background: transparent !important;
  border-radius: unset !important;
  color: #582e15 !important;
  width: 100% !important;
  font-size: 0.875rem !important;
  line-height: 1.25rem !important;
  font-family: "Quicksand", sans-serif !important;
}
:deep(.dp__input_icons) {
  padding: 0 !important;
}

.invalid {
  border-bottom: 1px solid red;
}
input {
  height: 52px;
  padding-right: 5px;
  color: #582e15;
  background: transparent;
  border: none;
  border-bottom: 1px solid #e3c2af;
  outline: none;
  position: relative;
}

.textarea {
  color: #582e15;
  background: transparent;
  border: none;
  border-bottom: 1px solid #e3c2af;
  outline: none;
  width: 100%;
  height: 52px;
}
.wrap-form {
  position: relative;
}

.wrap-form::after {
  content: "";
  position: absolute;
  width: 100%;
  height: 185%;
  bottom: 0;
  left: 0;
  background: url(../assets/register/bg-form.png);
  background-size: 100% 100%;
  pointer-events: none;
}

.wrap-form .head-w {
  overflow-x: hidden;
  padding: 74px 0 30px;
}

.wrap-form .title-main p {
  color: #fff;
}

.box-flex-sub {
  display: flex;
  justify-content: space-between;
  flex-wrap: wrap;
}

.box-form {
  max-width: 1120px;
  margin: 0 auto;
  /* padding: 105px 115px 80px; */
  background: url(../assets/register/nen-form.png) center center no-repeat;
  background-size: 100% 100%;
  position: relative;
  z-index: 10;
}

.box-form:before {
  content: "";
  position: absolute;
  width: 532px;
  height: 617px;
  left: calc(89%);
  background: url(../assets/register/meo3.png);
  bottom: 15%;
}

.box-form2 {
  position: relative;
}

.btn-readmore:before {
  content: "";
  position: absolute;
  width: 343px;
  height: 201px;
  right: -23rem;
  bottom: -7rem;
  background: url(/src/assets/register/cho-form.png);
  background-size: 48%;
  background-repeat: no-repeat;
  z-index: 100;
}

.title-form2::before {
  content: "";
  position: absolute;
  width: 265px;
  height: 287px;
  left: -18rem;
  bottom: calc(100% - 75px);
  background: url(../assets/register/meo2.png);
  z-index: 5;
}

.box-form:after {
  content: "";
  position: absolute;
  width: 394px;
  height: 451px;
  right: calc(100% - 65px);
  bottom: 0px;
  background: url(../assets/register/chofom2.png);
  z-index: 0;
}

.text-a.ip-input i {
}

.form-index1.was-validated i {
  display: none;
}

.title-form {
  text-align: center;
  position: relative;
  z-index: 2;
  margin-bottom: 50px;
}

.title-form span {
  font-size: 55px;
}

.title-form p {
  font-size: 25px;
  text-transform: capitalize;
}

.title-form2 {
  text-align: center;
  position: absolute;
  top: -30px;
  left: 50%;
  transform: translateX(-50%);
}

.title-form2 span {
  font-family: "iCiel Pony";
  font-size: 40px;
  color: #5f371a;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 460px;
  height: 112px;
  background: url(../assets/register/bg-title.png) center center no-repeat;
  padding-bottom: 13px;
  padding-right: 15px;
}

/* footer */
.footer-copyright span {
}

/* album */
.album-pos {
}

.wrap-ha {
  padding: 40px 0 70px;
}

.wrap-ha .head-w:after {
  content: "";
  position: absolute;
  width: 413px;
  height: 264px;
  bottom: 86%;
  right: 0;
  background: url(../assets/register/2cho.png);
}

.wrap-ha .logo-title {
  margin-left: 0;
  margin-right: 20px;
}

.wrap-ha .logo-title {
}

.img-album {
  display: block;
}

.album-item {
  position: relative;
  overflow: hidden;
  cursor: pointer;
  border-radius: 20px;
}

.album-item:hover .content-album {
  transition: 0.6s all;
  transform: translateY(0px);
  pointer-events: none;
}

.content-album h3 {
  margin-bottom: 0;
  padding: 11px 10px;
  position: relative;
}

.content-album h3:after {
  content: "";
  position: absolute;
  height: 30px;
  width: 100%;
  left: 0;
  bottom: calc(100% - 1px);
  background: url(../assets/register/line-items-kg.png);
}

.album-item:hover .content-album h3 a {
  color: var(--color-hover);
}

.album-item {
}

.album-item a {
}

.album-item a img {
}

.content-album {
  position: absolute;
  bottom: 0;
  width: 100%;
  background: #583014;
  text-align: center;
  transition: 0.6s all;
  transform: translateY(0);
}

.content-album h3 a {
  color: #fff;
  margin-bottom: 0;
  text-align: center;
  font-size: 25px;
  font-style: normal;
  line-height: normal;
  text-transform: capitalize;
  -webkit-line-clamp: 2;
}

.box-album {
  display: flex;
  justify-content: space-between;
  flex-wrap: wrap;
  position: relative;
  z-index: 2;
}

.dln {
  display: none;
}

.left-album {
  width: 37.693%;
}

.right-album {
  width: 59.84%;
  display: flex;
  flex-wrap: wrap;
  grid-gap: 28px;
}

.right-album .album-item {
  width: calc(50% - 14px);
}

.right-abum {
}

@keyframes spin2 {
  0% {
    transform: translate(-50%, -50%) rotate(0deg);
  }

  50% {
    transform: translate(-50%, -50%) rotate(360deg);
  }

  100% {
    transform: translate(-50%, -50%) rotate(0deg);
  }
}

.left-product {
  width: 270px;
}

.right-product {
  width: calc(100% - 300px);
}

.aside--sticky {
  position: -webkit-sticky;
  position: sticky;
  top: 130px;
}

.group-sidebox {
  position: relative;
  padding: 10px 10px;
  border: 1px solid #e7e7e7;
  background-color: #fff;
  border-radius: 12px;
}

.group-sidebox .sidebox-title h3 {
  font-size: 18px;
  text-transform: uppercase;
  margin-bottom: 10px;
  padding-bottom: 10px;
  border-bottom: 2px solid #323232;
  text-align: center;
  position: relative;
  color: var(--main-color);
  font-weight: 700;
  font-family: var(--font-main);
}

.sidebox-content ul {
  list-style: none;
  padding: 0px;
}

.menuList-links {
  margin: 0;
}

.menuList-links li {
  position: relative;
}

.menuList-links li a {
  color: #252a2b;
  position: relative;
  font-size: 14px;
  display: block;
  font-family: var(--font-main);
}

.menuList-links li a:hover,
.menuList-links li a:focus {
  color: var(--hover-color);
}

.menuList-links > li {
  border-bottom: 1px solid #e7e7e7;
}

.menuList-links > li:last-child {
  border-bottom: none;
}

.menuList-links > li > a {
  padding: 12px 0;
  font-weight: 500;
  font-size: 15px;
  text-transform: capitalize;
}

.menuList-links > li.has-submenu > a {
  padding-right: 30px;
}

.menuList-links > li.has-submenu .icon-plus-submenu:hover {
  border: 1px solid #e7e7e7;
}

ul.menuList-links li ul.submenu-links {
  display: none;
}

ul.submenu-links li a {
  padding: 8px 0 8px 0px;
}

li.has-submenu.level0 > ul.submenu-links {
  border-top: 1px dashed #e7e7e7;
}

li.has-submenu.level0 > ul.submenu-links li a {
  padding-left: 12px;
}

li.has-submenu.level1 > ul.submenu-links li a {
  padding-left: 25px;
}

.menuList-links > li.has-submenu span.icon-plus-submenu {
  width: 25px;
  height: 25px;
  cursor: pointer;
  position: absolute;
  right: 0;
  top: 0;
  bottom: 0;
  margin: auto;
  border: 1px solid transparent;
}

.icon-plus-submenu:after,
.icon-plus-submenu:before {
  background: rgba(9, 9, 9, 0.6);
  content: "";
  display: block;
  position: absolute;
  margin-right: 7px;
  top: 50%;
  right: 0;
  -moz-transition: all 0.25s linear;
  -o-transition: all 0.25s linear;
  -webkit-transition: all 0.25s linear;
  transition: all 0.25s linear;
}

.icon-plus-submenu:before {
  width: 9px;
  height: 1px;
  -moz-transform: translateY(-50%);
  -ms-transform: translateY(-50%);
  -webkit-transform: translateY(-50%);
  transform: translateY(-50%);
}

.icon-plus-submenu:after {
  width: 1px;
  height: 9px;
  right: 4px;
  transform-origin: center;
  -moz-transform: translateY(-50%) scale(1, 1);
  -ms-transform: translateY(-50%) scale(1, 1);
  -webkit-transform: translateY(-50%) scale(1, 1);
  transform: translateY(-50%) scale(1, 1);
}

li.has-submenu.opened > a > .icon-plus-submenu:after {
  display: none;
}

.box-form2.form-modal:after {
  display: none;
}

.form-modal .box-form:after,
.form-modal .box-form::before {
  display: none;
}

.box-form2.form-modal::before {
  right: 0;
}

#datlich .modal-content {
  background: #f1e2d7;
}

.choose_list {
  margin-bottom: 20px;
}

.choose_list span {
  display: inline-flex;
  min-width: 100px;
  height: 38px;
  border-radius: 4px;
  border: 1px solid var(--main-color);
  background: #fff;
  color: var(--main-color);
  padding: 0 10px;
  align-items: center;
  justify-content: center;
  text-transform: capitalize;
  font-size: 18px;
  cursor: pointer;
  margin: 0 5px;
}

.choose_list span.choosed {
  background: var(--main-color);
  color: #fff;
}

.choose_list {
  overflow-x: overlay;
  white-space: nowrap;
  padding: 0;
  padding-bottom: 5px;
}

.choose_list::-webkit-scrollbar-track {
  -webkit-box-shadow: inset 0 0 6px rgba(0, 0, 0, 0.3);
  background-color: #f5f5f5;
  border-radius: 50px;
}

.choose_list::-webkit-scrollbar {
  height: 3px;
  background-color: #f5f5f5;
}

.choose_list::-webkit-scrollbar-thumb {
  background-color: var(--main-color);
}

.btn-sub {
  outline: 0;
  box-shadow: unset;
  color: var(--chu2, #583014);
  text-align: center;
  font-size: 20px;
  font-style: normal;
  font-weight: 700;
  line-height: normal;
  text-transform: uppercase;
  border: 0;
}
.btn-readmore {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 251px;
  height: 61px;
  color: #582e15;
  position: relative;
  font-size: 20px;
  background: url(../assets/register/readmore-about.png) center center no-repeat;
  align-items: center;
}
.btn-sub i {
  margin-left: 20px;
  position: relative;
  z-index: 100;
  color: #fff;
}

.btn-sub:hover {
  border-color: var(--color-hover);
}

.btn-w {
  width: 100%;
}

.btn-w p {
  margin-bottom: 0;
  text-align: center;
}
</style>
