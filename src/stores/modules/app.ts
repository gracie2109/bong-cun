import {defineStore} from 'pinia';
import {DEFAULT_LAYOUT, DEFAULT_THEME} from "@/setting";
import type {IPAGE_LAYOUT, IPAGE_THEME} from "@/types";
import {LOCAL_STORAGE_KEY} from "@/lib/constants";

export const useAppStore = defineStore('app', () => {

    // Cookies instead of localStorage so the server renders the same values.
    const layout = useCookie<IPAGE_LAYOUT>(LOCAL_STORAGE_KEY.LAYOUT, {default: () => DEFAULT_LAYOUT});
    const theme = useCookie<IPAGE_THEME>(LOCAL_STORAGE_KEY.THEME, {default: () => DEFAULT_THEME});

    function setLayout(name: IPAGE_LAYOUT) {
        layout.value = name;
    }

    function setTheme(name: IPAGE_THEME) {
        theme.value = name;
    }

    return {
        layout,
        theme,
        setLayout,
        setTheme
    }
})
