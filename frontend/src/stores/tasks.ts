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
        ? `/api/tasks?session_id=${sessionId}`
        : "/api/tasks";
      const data = await api.get<{ tasks: Task[] }>(path);
      if (sessionId) {
        tasks.value = [
          ...tasks.value.filter((t) => t.sessionId !== sessionId),
          ...data.tasks,
        ];
      } else {
        tasks.value = data.tasks;
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

  async function approveTask(taskId: string) {
    try {
      const data = await api.post<{ task: Task }>(`/api/tasks/${taskId}/approve`, {});
      updateTask(data.task);
    } catch {
      // TODO: error handling
    }
  }

  async function rejectTask(taskId: string) {
    try {
      const data = await api.post<{ task: Task }>(`/api/tasks/${taskId}/reject`, {});
      updateTask(data.task);
    } catch {
      // TODO: error handling
    }
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
    approveTask,
    rejectTask,
  };
});
