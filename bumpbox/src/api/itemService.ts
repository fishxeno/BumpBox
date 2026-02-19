import {
    useAPIMutation,
    useAPIQuery,
    type BumpMutationOptions,
} from "./simpleAPI";

export const itemQueries = {
    ITEM: (itemId: number) => ["item", itemId] as const,
};

export const itemBaseRoute = "/api/items";

export function useItem(itemId: number) {
    return useAPIQuery(itemQueries.ITEM(itemId), `${itemBaseRoute}/${itemId}`);
}

interface CreateItemInterface {
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

