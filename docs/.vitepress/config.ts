import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'James the Butler',
  description: 'AI-native agent platform docs',
  srcDir: '.',
  outDir: '.vitepress/dist',
  ignoreDeadLinks: true,

  themeConfig: {
    logo: '/logo.svg',

    nav: [
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'Platform Spec', link: '/spec/platform' },
      { text: 'ADRs', link: '/adr/README' },
      {
        text: 'GitHub',
        link: 'https://github.com/andreburgstahler/james-the-butler',
      },
    ],

    sidebar: [
      {
        text: 'Getting Started',
        items: [
          { text: 'Introduction', link: '/guide/getting-started' },
          { text: 'Agent Guidelines', link: '/agents' },
        ],
      },
      {
        text: 'Platform Spec',
        items: [
          { text: 'Overview', link: '/spec/index' },
          { text: 'Platform (v1.5)', link: '/spec/platform' },
          { text: 'Architecture', link: '/spec/architecture' },
          { text: 'Security', link: '/spec/security' },
          { text: 'API Reference', link: '/spec/api' },
          { text: 'Database Schema', link: '/spec/database' },
          { text: 'WebRTC Streaming', link: '/spec/webrtc' },
        ],
      },
      {
        text: 'Components',
        items: [
          { text: 'Backend (Elixir/Phoenix)', link: '/spec/elixir' },
          { text: 'Frontend (Vue 3 / Tauri)', link: '/spec/vue' },
          { text: 'Mobile (Flutter)', link: '/spec/flutter' },
          { text: 'Pipeline Runner', link: '/spec/pipeline' },
          { text: 'Office Add-ins', link: '/spec/office-addins' },
          { text: 'Chrome Extension', link: '/spec/chrome-extension' },
        ],
      },
      {
        text: 'Architecture Decision Records',
        items: [
          { text: 'ADR Index', link: '/adr/README' },
          { text: 'ADR-001: Multi-platform Architecture', link: '/adr/001-multi-platform-architecture' },
          { text: 'ADR-002: Zero-install Principle', link: '/adr/002-zero-install-principle' },
          { text: 'ADR-003: Elixir/Phoenix Backend', link: '/adr/003-elixir-phoenix-backend' },
          { text: 'ADR-004: Vue 3 Frontend', link: '/adr/004-vue3-frontend' },
          { text: 'ADR-005: Flutter Mobile', link: '/adr/005-flutter-mobile' },
          { text: 'ADR-006: Python/Poetry Pipeline', link: '/adr/006-python-poetry-pipeline' },
          { text: 'ADR-007: Test Coverage Targets', link: '/adr/007-test-coverage-targets' },
          { text: 'ADR-008: Archgate Enforcement', link: '/adr/008-archgate-enforcement' },
          { text: 'ADR-009: Git Identity', link: '/adr/009-git-identity-and-repo-awareness' },
          { text: 'ADR-010: Session Compaction', link: '/adr/010-session-compaction' },
          { text: 'ADR-011: GEPA Skill Evolution', link: '/adr/011-gepa-skill-evolution' },
          { text: 'ADR-012: CLI as Escript', link: '/adr/012-cli-escript' },
        ],
      },
    ],

    search: {
      provider: 'local',
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/andreburgstahler/james-the-butler' },
    ],

    footer: {
      message: 'James the Butler — AI-native agent platform',
      copyright: 'MIT License',
    },
  },
})
