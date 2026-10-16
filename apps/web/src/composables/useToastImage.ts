import {h,markRaw} from "vue";
import {truncateText} from "@/lib/utils";
import {toast,} from "vue-sonner";

type ToastType = 'success' | 'info' | 'warning' | 'error' | 'loading'

type Props = {
    data:{
        image: string,
        message: string,
        desc: string
    },
    status?: ToastType
}

const renderUi = (payload: Props) => {
    return markRaw(h('div', { class: 'flex items-start justify-between w-full gap-4' }, [
        h('img', {
            src: payload.data.image,
            alt: '',
            class: 'w-20 h-20 object-cover aspect-square'
        }),
        h('div', {class:'grid gap-y-2'},[
            h('p', {}, truncateText(payload.data.message, 40)),
            h('p', {}, truncateText(payload.data.desc, 40))
        ])
    ]))
}

export function useToastImage(payload: Props) {
    if(payload.status) toast[payload.status](renderUi(payload));
    else toast(renderUi(payload));

}