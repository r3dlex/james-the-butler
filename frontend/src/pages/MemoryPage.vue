<template>
  <div class="p-6">
    <div class="mb-4 flex items-center justify-between">
      <h1 class="text-lg font-medium" style="color: var(--color-text)">Memory</h1>
      <input
        v-model="searchQuery"
        type="text"
        placeholder="Search memories..."
        class="rounded border bg-transparent px-3 py-1.5 text-sm outline-none focus:border-[var(--color-gold)]"
        style="border-color: var(--color-border); color: var(--color-text)"
      />
    </div>

    <LoadingSpinner v-if="loading" />

    <EmptyState v-else-if="filteredMemories.length === 0" message="No memories yet. Memories are extracted automatically from conversations." />

    <div v-else class="space-y-2">
      <div
        v-for="memory in filteredMemories"
        :key="memory.id"
        class="group rounded-md border p-3"
        style="border-color: var(--color-border)"
      >
        <div class="flex items-start justify-between gap-3">
          <!-- Memory content (editable) -->
          <div class="min-w-0 flex-1">
            <div v-if="editingId === memory.id">
              <textarea
                ref="editRef"
                v-model="editContent"
                class="w-full rounded border bg-transparent px-2 py-1 text-sm outline-none focus:border-[var(--color-gold)]"
                style="border-color: var(--color-border); color: var(--color-text)"
                rows="2"
                @keydown.enter.meta="saveEdit(memory)"
                @keydown.escape="cancelEdit"
              />
              <div class="mt-1 flex gap-2">
                <button
                  class="rounded px-2 py-0.5 text-xs font-medium"
                  style="background: var(--color-gold); color: var(--color-navy-deep)"
                  @click="saveEdit(memory)"
                >
                  Save
                </button>
                <button
                  class="text-xs"
                  style="color: var(--color-text-dim)"
                  @click="cancelEdit"
                >
                  Cancel
                </button>
              </div>
            </div>
            <p v-else class="text-sm" style="color: var(--color-text)">
              {{ memory.content }}
            </p>

            <!-- Source session link -->
            <div class="mt-1 flex items-center gap-2">
              <span class="text-[10px]" style="color: var(--color-text-dim)">
                {{ formatDate(memory.createdAt) }}
              </span>
              <router-link
                v-if="memory.sourceSessionId"
                :to="`/sessions/${memory.sourceSessionId}`"
                class="text-[10px] underline"
                style="color: var(--color-accent-blue)"
              >
                Source session
              </router-link>
            </div>
          </div>

          <!-- Actions -->
          <div class="flex gap-1 opacity-0 transition-opacity group-hover:opacity-100">
            <button
              class="rounded p-1 transition-colors hover:bg-[var(--color-surface)]"
              title="Edit"
              @click="startEdit(memory)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color: var(--color-text-dim)">
                <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
              </svg>
            </button>
            <button
              class="rounded p-1 transition-colors hover:bg-[var(--color-surface)]"
              title="Delete"
              @click="deleteMemory(memory)"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color: var(--color-risk-red)">
                <path d="M3 6h18" /><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" /><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { api } from "@/services/api";
import LoadingSpinner from "@/components/common/LoadingSpinner.vue";
import EmptyState from "@/components/common/EmptyState.vue";

interface Memory {
  id: string;
  content: string;
  sourceSessionId: string | null;
  createdAt: string;
}

const memories = ref<Memory[]>([]);
const loading = ref(false);
const searchQuery = ref("");
const editingId = ref<string | null>(null);
const editContent = ref("");

const filteredMemories = computed(() => {
  const q = searchQuery.value.toLowerCase();
  if (!q) return memories.value;
  return memories.value.filter((m) => m.content.toLowerCase().includes(q));
});

async function fetchMemories() {
  loading.value = true;
  try {
    const data = await api.get<{ memories: Memory[] }>("/api/memories");
    memories.value = data.memories;
  } catch {
    memories.value = [];
  } finally {
    loading.value = false;
  }
}

function startEdit(memory: Memory) {
  editingId.value = memory.id;
  editContent.value = memory.content;
}

function cancelEdit() {
  editingId.value = null;
  editContent.value = "";
}

async function saveEdit(memory: Memory) {
  const trimmed = editContent.value.trim();
  if (!trimmed || trimmed === memory.content) {
    cancelEdit();
    return;
  }
  try {
    const data = await api.put<{ memory: Memory }>(`/api/memories/${memory.id}`, {
      content: trimmed,
    });
    const idx = memories.value.findIndex((m) => m.id === memory.id);
    if (idx !== -1) memories.value[idx] = data.memory;
    cancelEdit();
  } catch {
    // keep editing on error
  }
}

async function deleteMemory(memory: Memory) {
  try {
    await api.delete(`/api/memories/${memory.id}`);
    memories.value = memories.value.filter((m) => m.id !== memory.id);
  } catch {
    // ignore
  }
}

function formatDate(dateStr: string): string {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  return d.toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

onMounted(fetchMemories);
</script>
