import { ref } from "vue";
import type { FileAttachment } from "@/types/message";

export function useFileUpload() {
  const uploading = ref(false);
  const uploadError = ref<string | null>(null);

  async function upload(
    file: File,
    sessionId: string,
  ): Promise<FileAttachment | null> {
    uploading.value = true;
    uploadError.value = null;

    try {
      const formData = new FormData();
      formData.append("file", file);

      const res = await fetch(
        `${import.meta.env.VITE_API_URL || "http://localhost:4000"}/api/sessions/${sessionId}/attachments`,
        {
          method: "POST",
          body: formData,
          headers: {
            Authorization: `Bearer ${localStorage.getItem("auth_token") || ""}`,
          },
        },
      );

      if (!res.ok) throw new Error("Upload failed");
      return await res.json();
    } catch (err: unknown) {
      uploadError.value = err instanceof Error ? err.message : "Upload failed";
      return null;
    } finally {
      uploading.value = false;
    }
  }

  return { upload, uploading, uploadError };
}
