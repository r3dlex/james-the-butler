export interface ApiError {
  error: string;
  detail?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  perPage: number;
  hasMore: boolean;
}

export interface ApiResponse<T> {
  data: T;
}
