import tseslint from "typescript-eslint";
import pluginVue from "eslint-plugin-vue";

export default [
  ...tseslint.configs.recommended,
  ...pluginVue.configs["flat/recommended"],
  {
    files: ["**/*.vue"],
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
      },
    },
  },
  {
    rules: {
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      "vue/multi-word-component-names": "off",
    },
  },
  // PrimeVue-first convention: discourage raw <button> in ui components dir.
  // Use PrimeVue Button instead (import from 'primevue/button').
  // Icon button wrappers (have class/style) are exempt.
  {
    files: ["src/components/ui/**/*.vue"],
    rules: {
      "vue/no-restricted-html-elements": [
        "warn",
        {
          element: "button",
          message:
            "Prefer PrimeVue Button component. Import: import Button from 'primevue/button'",
        },
      ],
    },
  },
  {
    ignores: ["dist/**", "node_modules/**", "src-tauri/**"],
  },
];