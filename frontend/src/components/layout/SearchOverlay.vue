<template>
  <div
    v-if="visible"
    class="fixed inset-0 z-50 flex items-start justify-center pt-20"
    @click.self="close"
  >
    <div
      class="w-full max-w-xl rounded-lg border shadow-2xl"
      style="background: var(--color-navy); border-color: var(--color-border)"
    >
      <!-- Search input -->
      <div
        class="flex items-center gap-2 border-b px-4 py-3"
        style="border-color: var(--color-border)"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          style="color: var(--color-text-dim)"
        >
          <circle cx="11" cy="11" r="8" />
          <line x1="21" y1="21" x2="16.65" y2="16.65" />
        </svg>
        <input
          ref="inputRef"
          v-model="query"
          type="text"
          placeholder="Search sessions and content..."
          class="flex-1 bg-transparent text-sm outline-none"
          style="color: var(--color-text)"
          @keydown.escape="close"
        />
        <kbd
          class="rounded border px-1.5 py-0.5 text-[10px]"
          style="
            border-color: var(--color-border);
            color: var(--color-text-dim);
          "
        >
          ESC
        </kbd>
      </div>

      <!-- Results -->
      <div class="max-h-96 overflow-y-auto">
        <div v-if="loading" class="flex justify-center py-8">
          <LoadingSpinner />
        </div>

        <div
          v-else-if="query && results.length === 0"
          class="px-4 py-6 text-center text-sm"
          style="color: var(--color-text-dim)"
        >
          No results found
        </div>

        <div v-else-if="results.length > 0">
          <button
            v-for="result in results"
            :key="`${result.sessionId}-${result.source}`"
            class="flex w-full flex-col gap-1 border-b px-4 py-3 text-left transition-colors hover:bg-[var(--color-surface)]"
            style="border-color: var(--color-border)"
            @click="goToSession(result.sessionId)"
          >
            <div class="flex items-center gap-2">
              <span
                class="text-sm font-medium"
                style="color: var(--color-text)"
              >
                {{ result.sessionName }}
              </span>
              <span
                class="rounded-full px-1.5 py-0.5 text-[10px]"
                style="
                  background: var(--color-surface);
                  color: var(--color-text-dim);
                "
              >
                {{ result.agentType }}
              </span>
            </div>
            <p
              class="line-clamp-2 text-xs"
              style="color: var(--color-text-dim)"
              v-html="result.excerpt"
            />
            <span class="text-[10px]" style="color: var(--color-text-dim)">
              {{ formatDate(result.lastUsedAt) }}
            </span>
          </button>
        </div>

        <div
          v-else
          class="px-4 py-6 text-center text-sm"
          style="color: var(--color-text-dim)"
        >
          Type to search across all sessions
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, nextTick } from "vue";
import { useRouter } from "vue-router";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";

interface SearchResult {
  sessionId: string;
  sessionName: string;
  agentType: string;
  hostId: string;
  excerpt: string;
  lastUsedAt: string;
  source: string;
}

const props = defineProps<{ visible: boolean }>();
const emit = defineEmits<{ close: [] }>();

const router = useRouter();
const query = ref("");
const results = ref<SearchResult[]>([]);
const loading = ref(false);
const inputRef = ref<HTMLInputElement | null>(null);

let debounceTimer: ReturnType<typeof setTimeout> | null = null;

watch(
  () => props.visible,
  (v) => {
    if (v) {
      query.value = "";
      results.value = [];
      nextTick(() => inputRef.value?.focus());
    }
  },
);

watch(query, (q) => {
  if (debounceTimer) clearTimeout(debounceTimer);
  if (!q.trim()) {
    results.value = [];
    return;
  }
  debounceTimer = setTimeout(() => doSearch(q), 250);
});

async function doSearch(q: string) {
  loading.value = true;
  try {
    const data = await api.get<{ results: SearchResult[] }>(
      `/api/search?q=${encodeURIComponent(q)}`,
    );
    results.value = data.results;
  } catch {
    results.value = [];
  } finally {
    loading.value = false;
  }
}

function goToSession(sessionId: string) {
  close();
  router.push(`/sessions/${sessionId}`);
}

function close() {
  emit("close");
}

function formatDate(dateStr: string): string {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  return d.toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}
</script>
