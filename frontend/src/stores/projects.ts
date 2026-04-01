import { defineStore } from "pinia";
import { ref } from "vue";
import { api } from "@/services/api";

export interface Project {
  id: string;
  name: string;
  description: string | null;
  executionMode: string | null;
  repoUrl: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface ProjectSession {
  id: string;
  name: string;
  agentType: string;
  status: string;
  lastUsedAt: string | null;
}

export const useProjectStore = defineStore("projects", () => {
  const projects = ref<Project[]>([]);
  const currentProject = ref<Project | null>(null);
  const currentProjectSessions = ref<ProjectSession[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function fetchProjects() {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.get<{ projects: Project[] }>("/api/projects");
      projects.value = data.projects;
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to fetch projects";
    } finally {
      loading.value = false;
    }
  }

  async function fetchProject(id: string) {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.get<{ project: Project }>(`/api/projects/${id}`);
      currentProject.value = data.project;
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to fetch project";
      currentProject.value = null;
    } finally {
      loading.value = false;
    }
  }

  async function fetchProjectSessions(projectId: string) {
    loading.value = true;
    error.value = null;
    try {
      const data = await api.get<{ sessions: ProjectSession[] }>(
        `/api/projects/${projectId}/sessions`,
      );
      currentProjectSessions.value = data.sessions;
    } catch (e: unknown) {
      error.value =
        e && typeof e === "object" && "error" in e
          ? String((e as { error: unknown }).error)
          : "Failed to fetch project sessions";
      currentProjectSessions.value = [];
    } finally {
      loading.value = false;
    }
  }

  return {
    projects,
    currentProject,
    currentProjectSessions,
    loading,
    error,
    fetchProjects,
    fetchProject,
    fetchProjectSessions,
  };
});
