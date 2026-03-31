import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { api } from "@/services/api";
import type { Task, TaskStatus } from "@/types/task";

export const useTaskStore = defineStore("tasks", () => {
  const tasks = ref<Task[]>([]);
  const loading = ref(false);

  const blockedTasks = computed(() =>
    tasks.value.filter((t) => t.status === "blocked"),
  );

  const activeTasks = computed(() =>
    tasks.value.filter((t) => t.status === "running" || t.status === "pending"),
  );

  function getTasksForSession(sessionId: string): Task[] {
    return tasks.value.filter((t) => t.sessionId === sessionId);
  }

  async function fetchTasks(sessionId?: string) {
    loading.value = true;
    try {
      const path = sessionId
        ? `/api/sessions/${sessionId}/tasks`
        : "/api/tasks";
      const data = await api.get<{ data: Task[] }>(path);
      if (sessionId) {
        tasks.value = [
          ...tasks.value.filter((t) => t.sessionId !== sessionId),
          ...data.data,
        ];
      } else {
        tasks.value = data.data;
      }
    } catch {
      // TODO: error handling
    } finally {
      loading.value = false;
    }
  }

  function updateTask(updated: Task) {
    const idx = tasks.value.findIndex((t) => t.id === updated.id);
    if (idx !== -1) {
      tasks.value[idx] = updated;
    } else {
      tasks.value.push(updated);
    }
  }

  function updateTaskStatus(taskId: string, status: TaskStatus) {
    const task = tasks.value.find((t) => t.id === taskId);
    if (task) task.status = status;
  }

  return {
    tasks,
    loading,
    blockedTasks,
    activeTasks,
    getTasksForSession,
    fetchTasks,
    updateTask,
    updateTaskStatus,
  };
});
