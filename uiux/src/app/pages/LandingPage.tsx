import { Link } from 'react-router';
import { Button } from '../components/ui/button';
import { Card, CardContent } from '../components/ui/card';
import { ShoppingBag, Store, Package, Lock } from 'lucide-react';

export function LandingPage() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-blue-50 to-purple-50">
      {/* Header */}
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-bold text-gray-900">BumpBox - Secondlife</h1>
            <Link to="/shop">
              <Button variant="outline">Browse Items</Button>
            </Link>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <div className="text-center mb-16">
          <h2 className="text-5xl font-bold text-gray-900 mb-6">
            Welcome to BumpBox - Secondlife
          </h2>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto mb-4">
            The smart way to buy and sell second-hand items with secure locker pickup
          </p>
          <p className="text-lg text-gray-500 max-w-2xl mx-auto">
            Whether you're a buyer looking for quality pre-loved items or a seller wanting 
            to give your items a second life, BumpBox makes it easy, safe, and convenient.
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid md:grid-cols-2 gap-8 mb-16">
          {/* For Buyers */}
          <Card className="border-2 border-blue-200 hover:shadow-lg transition-shadow">
            <CardContent className="p-8">
              <div className="flex items-center justify-center w-16 h-16 bg-blue-100 rounded-full mb-6">
                <ShoppingBag className="h-8 w-8 text-blue-600" />
              </div>
              <h3 className="text-2xl font-bold mb-4">For Buyers</h3>
              <ul className="space-y-3 text-gray-600">
                <li className="flex items-start">
                  <span className="text-blue-600 mr-2">•</span>
                  Browse quality second-hand items at great prices
                </li>
                <li className="flex items-start">
                  <span className="text-blue-600 mr-2">•</span>
                  Shop from the comfort of your home
                </li>
                <li className="flex items-start">
                  <span className="text-blue-600 mr-2">•</span>
                  Choose a convenient locker location near you
                </li>
                <li className="flex items-start">
                  <span className="text-blue-600 mr-2">•</span>
                  Pick up your items 24/7 with a secure access code
                </li>
              </ul>
              <Link to="/shop">
                <Button className="w-full mt-6" size="lg">
                  Start Shopping
                </Button>
              </Link>
            </CardContent>
          </Card>

          {/* For Sellers */}
          <Card className="border-2 border-purple-200 hover:shadow-lg transition-shadow">
            <CardContent className="p-8">
              <div className="flex items-center justify-center w-16 h-16 bg-purple-100 rounded-full mb-6">
                <Store className="h-8 w-8 text-purple-600" />
              </div>
              <h3 className="text-2xl font-bold mb-4">For Sellers</h3>
              <ul className="space-y-3 text-gray-600">
                <li className="flex items-start">
                  <span className="text-purple-600 mr-2">•</span>
                  List your items quickly and easily
                </li>
                <li className="flex items-start">
                  <span className="text-purple-600 mr-2">•</span>
                  Reach buyers in your local area
                </li>
                <li className="flex items-start">
                  <span className="text-purple-600 mr-2">•</span>
                  No need to meet buyers in person
                </li>
                <li className="flex items-start">
                  <span className="text-purple-600 mr-2">•</span>
                  Secure locker drop-off and payment
                </li>
              </ul>
              <Link to="/seller/create">
                <Button className="w-full mt-6" size="lg">
                  Start Selling
                </Button>
              </Link>
            </CardContent>
          </Card>
        </div>

        {/* How It Works */}
        <div className="bg-white rounded-2xl p-8 md:p-12 shadow-lg">
          <h3 className="text-3xl font-bold text-center mb-12">How It Works</h3>
          
          <div className="grid md:grid-cols-3 gap-8">
            <div className="text-center">
              <div className="flex items-center justify-center w-16 h-16 bg-blue-100 rounded-full mx-auto mb-4">
                <ShoppingBag className="h-8 w-8 text-blue-600" />
              </div>
              <h4 className="font-bold text-lg mb-2">1. Shop Online</h4>
              <p className="text-gray-600">
                Browse our marketplace and add items to your cart
              </p>
            </div>

            <div className="text-center">
              <div className="flex items-center justify-center w-16 h-16 bg-purple-100 rounded-full mx-auto mb-4">
                <Package className="h-8 w-8 text-purple-600" />
              </div>
              <h4 className="font-bold text-lg mb-2">2. Choose a Locker</h4>
              <p className="text-gray-600">
                Select a convenient pickup location from our network of secure lockers
              </p>
            </div>

            <div className="text-center">
              <div className="flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mx-auto mb-4">
                <Lock className="h-8 w-8 text-green-600" />
              </div>
              <h4 className="font-bold text-lg mb-2">3. Collect Your Item</h4>
              <p className="text-gray-600">
                Use your 6-digit access code to unlock and collect your items
              </p>
            </div>
          </div>
        </div>

        {/* CTA Section */}
        <div className="text-center mt-16">
          <Link to="/shop">
            <Button size="lg" className="text-lg px-8 py-6">
              Explore Items Now
            </Button>
          </Link>
        </div>
      </main>
    </div>
  );
}