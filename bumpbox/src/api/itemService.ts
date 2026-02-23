import {
    useAPIMutation,
    useAPIQuery,
    type BumpMutationOptions,
} from "./simpleAPI";

export const itemQueries = {
    ITEM: () => ["item"] as const,
};

export const itemBaseRoute = "/api/items";

interface GetItem {
    status: boolean;
    data: {
        id: number;
        item_name: string;
        phone: string;
        price: number;
        description: string;
        days: number;
    };
    message: string;
}

export function useItem() {
    return useAPIQuery<GetItem>(itemQueries.ITEM(), `/api/item`);
}

interface CreateItemInterface {
    phone: string;
    item_name: string;
    price: number;
    description: string;
    days: number;
}

export function useItemMutations<Key extends keyof typeof itemMutations>(
    key: Key,
) {
    //You won't get type suggestions in the mutate function without this assertion
    const mutationFn = itemMutations[key] as (
        params: Parameters<(typeof itemMutations)[Key]>[0],
    ) => BumpMutationOptions;
    return useAPIMutation(mutationFn);
}

export const itemMutations = {
  CREATE_ITEM: (item: CreateItemInterface) => ({
    url: "/api/item",
    method: "POST",
    requestBody: item,
  }) satisfies BumpMutationOptions<any, CreateItemInterface>,
};

