# ADR-013: PrimeVue v4 + Tailwind CSS v4 Migration

**Date**: 2026-04-14
**Status**: Accepted
**Deciders**: James the Butler platform team

## Context

The frontend (`frontend/`) is a Vue 3 + Vite + TypeScript web/desktop application (Tauri). It uses **Tailwind CSS v4** via `@tailwindcss/vite` with CSS custom properties as the design token layer. There was no component library for UI primitives. Custom components (`ConfirmDialog`, `ErrorBanner`, `StatusBadge`, etc.) provided basic UI but required ongoing maintenance.

The decision is to introduce **PrimeVue v4** as the component library, migrate all custom components to PrimeVue primitives, and establish an enforceable "PrimeVue-first" convention going forward.

## Decision

Adopt **PrimeVue v4** with `unstyled: true` mode and `@primevue/themes` for the frontend component layer. Tailwind CSS v4 is retained as the styling solution. Existing CSS custom properties (`--color-navy`, `--color-gold`, etc.) are preserved as PrimeVue theme token overrides via `@primevue/themes`'s `definePreset` API.

## Drivers

1. **Component library requirement**: Platform decision requires PrimeVue as the component library.
2. **Tailwind v4 compatibility**: PrimeVue v4's `unstyled` mode provides the cleanest Tailwind integration. PrimeVue v3 styles conflict with Tailwind v4 CSS specificity.
3. **Accessibility**: PrimeVue v4 components are ARIA-compliant out of the box.
4. **Maintenance reduction**: Migrating custom primitives to PrimeVue reduces ongoing maintenance burden.

## radix-vue Deprecation Decision

`radix-vue` was previously installed (v1.9.17) for accessibility primitives. Both `radix-vue` and PrimeVue v4 use `Teleport to="body"` for dialogs, dropdowns, and overlays, creating portal collision risk.

**Decision**: Deprecate `radix-vue` in favor of PrimeVue equivalents. All portal-based radix-vue components (Dialog, DropdownMenu, Popover, Tooltip) are replaced by PrimeVue `Dialog`, `Menu`, `Overlay` components. Non-portal radix-vue primitives (ToggleGroup, Checkbox, RadioGroup) are replaced by PrimeVue `ToggleButton`, `Checkbox`, `RadioButton`. `radix-vue` should be removed from `package.json` after Tier 2 migration is complete.

**Why not keep both**: With both libraries using portals, DOM nodes can render out of order or be clipped in layered overlay scenarios. Single-library approach eliminates this class of bug.

## Alternatives Considered

| Option | Verdict | Reason |
|--------|---------|--------|
| PrimeVue v3 (Styled) | **Rejected** | PrimeVue v3 styles conflict with Tailwind v4 by default — requires disabling `primeflex`, carefully scoping styles, and adding an extra CSS reset step. This defeats the "keep it working" constraint. |
| Quasar / Naive UI | **Rejected** | Explicitly contradicts the PrimeVue-first requirement. |
| Custom component library (new) | **Rejected** | Re-invents wheel; maintenance burden. |
| No component library (status quo) | **Rejected** | Does not satisfy the component library requirement. |

## Why Chosen: PrimeVue v4 (Unstyled Mode)

PrimeVue v4 with `unstyled` mode is the only PrimeVue version compatible with Tailwind v4 without style-scoping workarounds. The `unstyled` mode means PrimeVue provides accessible, composable component logic while Tailwind provides all visual styling — the best separation of concerns for this codebase.

PrimeVue v4 includes first-class Tailwind integration via `unstyled: true`, meaning PrimeVue provides accessible component logic and slot structure while Tailwind handles all visual styling. Theme token mapping is done via `@primevue/themes` `definePreset`.

## Consequences

### Positive
- Consistent accessible component API across all UI primitives
- Reduced custom component maintenance burden
- PrimeVue theming layer maps to existing design tokens, preserving dark theme visual identity
- `Toast`, `ConfirmDialog`, and `Dialog` available app-wide via singleton config

### Negative
- Migration effort is non-trivial (~15 components across Tier 1–2)
- PrimeVue v4 `unstyled` mode requires Tailwind class application on each component slot (lower automation than expected)
- `radix-vue` must be fully removed after migration
- ESLint enforcement rule must be carefully scoped to avoid false positives on intentional icon button wrappers

### Neutral
- `@primevue/themes` v4.5.4 is deprecated in favor of `@primeuix/themes` — monitor for migration path in future updates

## Implementation Summary

### Tier 0: Discovery + Preparation
- `radix-vue` audit: No portal usages found in codebase. Deprecation confirmed.
- `npm install primevue@^4 @primevue/themes`
- `main.ts` configured with `unstyled: true`, dark theme preset mapping `primary` to `--color-gold` and `colorScheme.dark.surface` to the existing navy palette

### Tier 1: Drop-in Primitive Replacements
| Component | PrimeVue Replacement | Status |
|-----------|----------------------|--------|
| `ConfirmDialog.vue` | `Dialog` + `Button` | Migrated |
| `ErrorBanner.vue` | `Message` | Migrated |
| `StatusBadge.vue` | `Tag` | Migrated |
| `LoadingSpinner.vue` | `ProgressSpinner` | Migrated |
| `EmptyState.vue` | `Card` | Migrated |
| `RiskBadge.vue` | `Tag` | Migrated |
| `TokenDisplay.vue` | Custom (PrimeVue `MeterGroup` not suitable) | Kept custom |

### Tier 2: Layout + Form-Heavy Components
| Component | PrimeVue Replacement | Status |
|-----------|----------------------|--------|
| `AppSidebar.vue` | No PrimeVue needed | Preserved as-is |
| `AppHeader.vue` | No PrimeVue needed | Preserved as-is |
| `SearchOverlay.vue` | `Dialog` | Migrated |
| `SettingsGeneralPage.vue` | `Select`, `InputSwitch` | Migrated |
| Other settings pages | Audit pending | Pending |

### Tier 3: Verification + Enforcement
- Full regression: `npm run build` passes, 406 tests pass
- ESLint rule: Scoped to `src/components/ui/` to flag bare `<button>` without class (custom button creation)
- ADR: This document

## Follow-ups

1. Remove `radix-vue` from `package.json` after Tier 2 session pages migration
2. Monitor `@primevue/themes` deprecation — plan migration to `@primeuix/themes` when available
3. Audit remaining settings pages (`SettingsChannelsPage`, `SettingsExecutionModePage`, etc.) for `<select>` and `<input type="checkbox">` patterns
4. Consider Playwright visual regression testing for migrated pages
5. Evaluate PrimeVue `DataTable` for session list pages