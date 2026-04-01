#!/usr/bin/env node
/**
 * Pre-build script: copies spec files and AGENTS.md into the docs tree
 * so VitePress can include them without symlinks.
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const docsDir = path.resolve(__dirname, '..')
const projectRoot = path.resolve(docsDir, '..')
const specSrc = path.join(projectRoot, 'spec')
const specDest = path.join(docsDir, 'spec')

// Ensure destination directories exist
fs.mkdirSync(specDest, { recursive: true })

// Copy all *.md files from spec/
const specFiles = fs.readdirSync(specSrc).filter(f => f.endsWith('.md'))
for (const file of specFiles) {
  fs.copyFileSync(path.join(specSrc, file), path.join(specDest, file))
  console.log(`Copied spec/${file} -> docs/spec/${file}`)
}

// Copy AGENTS.md as docs/agents.md
const agentsSrc = path.join(projectRoot, 'AGENTS.md')
const agentsDest = path.join(docsDir, 'agents.md')
fs.copyFileSync(agentsSrc, agentsDest)
console.log('Copied AGENTS.md -> docs/agents.md')

console.log('copy-specs: done')
