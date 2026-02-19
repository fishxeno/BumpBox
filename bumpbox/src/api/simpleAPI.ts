import axios, { type AxiosRequestConfig, type Method } from "axios";
import {
    useQuery,
    useMutation,
    useQueryClient,
    type QueryKey,
    type UseQueryOptions,
    type UseMutationOptions,
    type Updater,
} from "@tanstack/react-query";


function isLocalhost() {
  if (typeof window === "undefined") return false;

  const host = window.location.hostname;

  return (
    host === "localhost" ||
    host === "127.0.0.1" ||
    host === "[::1]"
  );
}

if (isLocalhost()) {
  axios.defaults.baseURL = "http://localhost:8080";
}


/* ---------------------------------- */
/* Custom Error */
/* ---------------------------------- */
export interface BumpMutationOptions<TData = any, TBody = unknown> {
    url: string;
    method: Method;
    requestBody?: TBody;
    /** `false` by default */
    useFormData?: boolean;
    /** Updater to run on the state (won't be run if the query hasn't been fetched yet) */
    updater?:
        |   Updater<TData, unknown>
        |   Array<Updater<TData, unknown>>
    /** Request config to pass to axios */
    axiosConfig?: Omit<AxiosRequestConfig, 'method' | 'data' | 'url'>;
}

export class APIError extends Error {
    status: number;

    constructor(message: string, status = 500) {
        super(message);
        this.status = status;
    }
}

function handleAxiosError(error: unknown): never {
    if (axios.isAxiosError(error)) {
        const status = error.response?.status ?? 500;

        const message =
            (error.response?.data as any)?.message ??
            error.message ??
            "Unexpected error";

        throw new APIError(message, status);
    }

    throw new APIError("Unexpected error");
}

/* ---------------------------------- */
/* GET Hook */
/* ---------------------------------- */

export function useAPIQuery<TData = unknown>(
    key: QueryKey,
    url: string,
    options?: Omit<UseQueryOptions<TData, APIError>, "queryKey" | "queryFn">,
) {
    return useQuery<TData, APIError>({
        queryKey: key,
        queryFn: async () => {
            try {
                const response = await axios.get<TData>(url);
                return response.data;
            } catch (err) {
                handleAxiosError(err);
            }
        },
        ...options,
    });
}

/* ---------------------------------- */
/* Mutation Hook */
/* ---------------------------------- */

export function useAPIMutation<
  TMutationFn extends (variables: any) => BumpMutationOptions<any, any>
>(
  mutationFn: TMutationFn,
  options?: Omit<
    UseMutationOptions<
      Awaited<ReturnType<TMutationFn>> extends BumpMutationOptions<infer TData, any>
        ? TData
        : never,
      APIError,
      Parameters<TMutationFn>[0]
    >,
    "mutationFn"
  >
) {
  const queryClient = useQueryClient();

  type TVariables = Parameters<TMutationFn>[0];
  type TData =
    Awaited<ReturnType<TMutationFn>> extends BumpMutationOptions<
      infer Data,
      any
    >
      ? Data
      : never;

  return useMutation<TData, APIError, TVariables>({
    mutationFn: async (variables) => {
      const config = mutationFn(variables);

      try {
        const response = await axios.request<TData>({
          url: config.url,
          method: config.method,
          data: config.requestBody ?? variables,
          ...config.axiosConfig,
        });

        // ✅ Restore updater logic safely
        if (config.updater) {
          const updaters = Array.isArray(config.updater)
            ? config.updater
            : [config.updater];

          updaters.forEach((updater) => {
            // IMPORTANT: QueryKey must be array
            queryClient.setQueryData([config.url], updater);
          });
        }

        return response.data;
      } catch (err) {
        handleAxiosError(err);
      }
    },
    ...options,
  });
}
