import { useParams, Link, useNavigate } from 'react-router';
import { mockItems } from '../data/items';
import { useCart } from '../context/CartContext';
import { Button } from '../components/ui/button';
import { Badge } from '../components/ui/badge';
import { Card, CardContent } from '../components/ui/card';
import { ArrowLeft, ShoppingCart, MapPin } from 'lucide-react';
import { ImageWithFallback } from '../components/figma/ImageWithFallback';

export function ItemDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { addToCart, getCartCount } = useCart();

  const item = mockItems.find((item) => item.id === id);

  if (!item) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-2xl font-bold mb-4">Item not found</h2>
          <Link to="/">
            <Button>Back to Home</Button>
          </Link>
        </div>
      </div>
    );
  }

  const handleAddToCart = () => {
    addToCart(item);
    navigate('/cart');
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

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Link to="/shop">
          <Button variant="ghost" className="mb-6">
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Items
          </Button>
        </Link>

        <div className="grid md:grid-cols-2 gap-8">
          {/* Image */}
          <div className="aspect-square overflow-hidden rounded-lg bg-white">
            <ImageWithFallback
              src={item.imageUrl}
              alt={item.title}
              className="w-full h-full object-cover"
            />
          </div>

          {/* Details */}
          <div>
            <div className="bg-white rounded-lg p-6">
              <div className="flex items-start justify-between mb-4">
                <h1 className="text-3xl font-bold text-gray-900">{item.title}</h1>
                <Badge variant="secondary" className="ml-4">
                  {item.condition}
                </Badge>
              </div>

              <div className="mb-6">
                <p className="text-4xl font-bold text-gray-900 mb-2">${item.price}</p>
                <Badge variant="outline">{item.category}</Badge>
              </div>

              <div className="mb-6">
                <h3 className="font-semibold mb-2">Description</h3>
                <p className="text-gray-600">{item.description}</p>
              </div>

              <div className="mb-6">
                <h3 className="font-semibold mb-2">Seller</h3>
                <p className="text-gray-600">{item.sellerName}</p>
              </div>

              <Card className="mb-6 bg-blue-50 border-blue-200">
                <CardContent className="p-4">
                  <div className="flex items-start space-x-3">
                    <MapPin className="h-5 w-5 text-blue-600 mt-0.5" />
                    <div>
                      <h4 className="font-semibold text-blue-900">Locker Pickup</h4>
                      <p className="text-sm text-blue-700">
                        Choose your preferred pickup location at checkout
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Button
                size="lg"
                className="w-full"
                onClick={handleAddToCart}
              >
                Add to Cart
              </Button>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}