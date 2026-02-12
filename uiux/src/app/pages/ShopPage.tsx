import { Link } from 'react-router';
import { mockItems } from '../data/items';
import { useCart } from '../context/CartContext';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Card, CardContent, CardFooter } from '../components/ui/card';
import { ShoppingCart } from 'lucide-react';
import { ImageWithFallback } from '../components/figma/ImageWithFallback';

export function ShopPage() {
  const { addToCart, getCartCount } = useCart();

  const handleAddToCart = (e: React.MouseEvent, item: any) => {
    e.preventDefault();
    addToCart(item);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white shadow-sm sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between">
            <Link to="/" className="flex items-center space-x-2">
              <h1 className="text-2xl font-bold text-gray-900">BumpBox - Secondlife</h1>
            </Link>
            <Link to="/cart">
              <Button variant="outline" className="relative">
                <ShoppingCart className="h-5 w-5" />
                {getCartCount() > 0 && (
                  <Badge className="absolute -top-2 -right-2 h-5 w-5 flex items-center justify-center p-0">
                    {getCartCount()}
                  </Badge>
                )}
              </Button>
            </Link>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-4xl font-bold mb-4">Buy Second-Hand, Collect from a Locker</h2>
          <p className="text-xl opacity-90">
            Shop quality pre-loved items and pick them up at your convenience
          </p>
        </div>
      </div>

      {/* Items Grid */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="mb-8">
          <h3 className="text-2xl font-bold text-gray-900">Available Items</h3>
          <p className="text-gray-600 mt-2">Browse our collection of quality second-hand items</p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {mockItems.map((item) => (
            <Link to={`/item/${item.id}`} key={item.id}>
              <Card className="h-full hover:shadow-lg transition-shadow">
                <CardContent className="p-0">
                  <div className="aspect-square overflow-hidden rounded-t-lg">
                    <ImageWithFallback
                      src={item.imageUrl}
                      alt={item.title}
                      className="w-full h-full object-cover hover:scale-105 transition-transform"
                    />
                  </div>
                  <div className="p-4">
                    <div className="flex items-start justify-between mb-2">
                      <h4 className="font-semibold text-lg">{item.title}</h4>
                      <Badge variant="secondary" className="ml-2 shrink-0">
                        {item.condition}
                      </Badge>
                    </div>
                    <p className="text-sm text-gray-600 mb-2">{item.category}</p>
                    <p className="text-2xl font-bold text-gray-900">${item.price}</p>
                  </div>
                </CardContent>
                <CardFooter className="p-4 pt-0">
                  <Button
                    className="w-full"
                    onClick={(e) => handleAddToCart(e, item)}
                  >
                    Add to Cart
                  </Button>
                </CardFooter>
              </Card>
            </Link>
          ))}
        </div>
      </main>
    </div>
  );
}
