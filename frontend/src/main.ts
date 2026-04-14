import { createApp } from "vue";
import { createPinia } from "pinia";
import router from "./router";
import PrimeVue from "primevue/config";
import Aura from "@primevue/themes/aura";
import { definePreset } from "@primevue/themes";
import ConfirmationService from "primevue/confirmationservice";
import ToastService from "primevue/toastservice";
import App from "./App.vue";
import "./assets/main.css";
import { applyPersistedTheme } from "./utils/theme";

// Apply saved theme before the first paint to avoid flash
applyPersistedTheme();

// Define a dark preset that maps PrimeVue tokens to our existing CSS variables
const JamesPreset = definePreset(Aura, {
  semantic: {
    primary: {
      50: "#fdf8f3",
      100: "#f9ede0",
      200: "#f0d7bb",
      300: "#e5be92",
      400: "#d4a574",
      500: "#c49365",
      600: "#a87d55",
      700: "#8c6746",
      800: "#705138",
      900: "#5a432e",
      950: "#4a3728",
      contrast: {
        50: "#0d0d1a",
        100: "#0d0d1a",
        200: "#0d0d1a",
        300: "#0d0d1a",
        400: "#ffffff",
        500: "#ffffff",
        600: "#ffffff",
        700: "#ffffff",
        800: "#ffffff",
        900: "#ffffff",
        950: "#ffffff",
      },
    },
    colorScheme: {
      dark: {
        surface: {
          0: "#0d0d1a",
          50: "#12121f",
          100: "#1a1a2e",
          200: "#1e1e36",
          300: "#252544",
          400: "#2a2a3e",
          500: "#32324d",
          600: "#3e3e5e",
          700: "#525272",
          800: "#6e6e8e",
          900: "#9898a8",
          950: "#e0e0e0",
        },
      },
    },
  },
});

const app = createApp(App);
app.use(createPinia());
app.use(router);
app.use(PrimeVue, {
  unstyled: true,
  theme: {
    preset: JamesPreset,
    options: {
      darkModeSelector: ".dark",
    },
  },
});
app.use(ToastService);
app.use(ConfirmationService);

app.mount("#app");
