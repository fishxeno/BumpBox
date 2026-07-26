import { useAPIMutation, useAPIQuery, type BumpMutationOptions } from "./simpleAPI"
import Stripe from 'stripe';
export const stripeBaseRoute = `/api/stripe`

export const StripeQueries = {
    // CUSTOMER_PORTAL: (orgId: number, redirectUrl: string) => ['stripe', 'customer', orgId, 'portal', redirectUrl] as const,
    ITEMS: ['items'] as const,
    INVOICES: (phoneNumber: string) => ['stripe', 'customer', 'organisation', 'invoice', phoneNumber] as const,
    // RECEIPTPDF: (receiptUrl: string) => ['stripe', 'customer', 'receipt', receiptUrl] as const,
}

// export function useCustomerPortal(orgId: number, redirectUrl: string) {
//     return useKoinosAPI<string>(
//         StripeQueries.CUSTOMER_PORTAL(orgId, redirectUrl),
//         `/api/stripe/customer/organisation/${orgId}/portal?ru=${redirectUrl}`
//     );
// }

export function useItems() {
    return useAPIQuery<Stripe.Response<Stripe.ApiList<Stripe.Product>>>(
        StripeQueries.ITEMS,
        `/api/items`
    );
}

export function useInvoices(phoneNumber: string) {
    return useAPIQuery<Stripe.Response<Stripe.ApiList<Stripe.Invoice>>>(
        StripeQueries.INVOICES(phoneNumber),
        `/api/stripe/customer/organisation/invoice?pn=${phoneNumber}`
    )
}


const StripeMutations = {}

export function useStripeMutations<Key extends keyof typeof StripeMutations>(key: Key) {
    //You won't get type suggestions in the mutate function without this assertion
    const mutationFn = StripeMutations[key] as (
        params: Parameters<typeof StripeMutations[Key]>[0]
    ) => BumpMutationOptions;
    return useAPIMutation(mutationFn);
}
