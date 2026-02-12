import { createBrowserRouter } from 'react-router';
import { LandingPage } from './pages/LandingPage';
import { ShopPage } from './pages/ShopPage';
import { ItemDetailPage } from './pages/ItemDetailPage';
import { CartPage } from './pages/CartPage';
import { CheckoutPage } from './pages/CheckoutPage';
import { ReceiptPage } from './pages/ReceiptPage';
import { CreateListingPage } from './pages/CreateListingPage';
import { SellerConfirmationPage } from './pages/SellerConfirmationPage';

export const router = createBrowserRouter([
  {
    path: '/',
    Component: LandingPage,
  },
  {
    path: '/shop',
    Component: ShopPage,
  },
  {
    path: '/item/:id',
    Component: ItemDetailPage,
  },
  {
    path: '/cart',
    Component: CartPage,
  },
  {
    path: '/checkout',
    Component: CheckoutPage,
  },
  {
    path: '/confirmation',
    Component: ReceiptPage,
  },
  {
    path: '/seller/create',
    Component: CreateListingPage,
  },
  {
    path: '/seller/confirmation',
    Component: SellerConfirmationPage,
  },
]);