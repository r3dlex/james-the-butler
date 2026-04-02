import { createApp } from "vue";
import { createPinia } from "pinia";
import router from "./router";
import App from "./App.vue";
import "./assets/main.css";
import { applyPersistedTheme } from "./utils/theme";

// Apply saved theme before the first paint to avoid flash
applyPersistedTheme();

const app = createApp(App);
app.use(createPinia());
app.use(router);
app.mount("#app");
