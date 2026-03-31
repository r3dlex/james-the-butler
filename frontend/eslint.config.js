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
  {
    ignores: ["dist/**", "node_modules/**", "src-tauri/**"],
  },
];
