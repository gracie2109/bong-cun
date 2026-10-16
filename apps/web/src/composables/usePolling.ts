import { ref, onMounted, onUnmounted } from 'vue';

type Props = {
    callback: () => void;
    waitTime?: number;
    isPolling?: boolean;
};

export function usePolling({ callback, waitTime = 15000,isPolling = false }: Props) {
    const intervalId = ref<number | null>(null);

    const startPolling = () => {
        if (intervalId.value !== null) return;
        intervalId.value = window.setInterval(() => {
            callback();
        }, waitTime);
    };

    const stopPolling = () => {
        if (intervalId.value !== null) {
            window.clearInterval(intervalId.value);
            intervalId.value = null;
        }
    };

    onMounted(() => {
        if(isPolling){
            startPolling();
        }
    });

    onUnmounted(() => {
        stopPolling();
    });
}
