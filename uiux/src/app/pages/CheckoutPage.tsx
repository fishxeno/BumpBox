import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router';
import { useCart } from '../context/CartContext';
import { mockLockers } from '../data/items';
import { Button } from '../components/ui/button';
import { Card, CardContent } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { RadioGroup, RadioGroupItem } from '../components/ui/radio-group';
import { ArrowLeft, MapPin, Clock } from 'lucide-react';

export function CheckoutPage() {
  const navigate = useNavigate();
  const { cart, getCartTotal, clearCart } = useCart();
  const [selectedLocker, setSelectedLocker] = useState(mockLockers[0].id);
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [isCheckingOut, setIsCheckingOut] = useState(false);

  useEffect(() => {
    if (cart.length === 0 && !isCheckingOut) {
      navigate('/cart');
    }
  }, [cart.length, navigate, isCheckingOut]);

  const handleCheckout = () => {
    setIsCheckingOut(true);
    // Generate a 6-digit numerical passcode
    const accessCode = Math.floor(100000 + Math.random() * 900000).toString();
    
    // Store order info in sessionStorage for the receipt page
    const order = {
      id: Date.now().toString(),
      items: cart,
      total: getCartTotal() + 5,
      locker: mockLockers.find((l) => l.id === selectedLocker)!,
      date: new Date().toISOString(),
      status: 'Processing',
      accessCode,
      email,
      phone,
    };
    
    sessionStorage.setItem('lastOrder', JSON.stringify(order));
    clearCart();
    navigate('/confirmation');
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
          <Link to="/" className="flex items-center space-x-2">
            <h1 className="text-2xl font-bold text-gray-900">BumpBox - Secondlife</h1>
          </Link>
        </div>
      </header>

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Link to="/cart">
          <Button variant="ghost" className="mb-6">
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Cart
          </Button>
        </Link>

        <h1 className="text-3xl font-bold mb-8">Checkout</h1>

        <div className="grid lg:grid-cols-3 gap-8">
          {/* Checkout Form */}
          <div className="lg:col-span-2 space-y-6">
            {/* Contact Information */}
            <Card>
              <CardContent className="p-6">
                <h2 className="text-xl font-bold mb-4">Contact Information</h2>
                <div className="space-y-4">
                  <div>
                    <Label htmlFor="email">Email</Label>
                    <Input
                      id="email"
                      type="email"
                      placeholder="your@email.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor="phone">Phone Number</Label>
                    <Input
                      id="phone"
                      type="tel"
                      placeholder="(555) 123-4567"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      required
                    />
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Locker Selection */}
            <Card>
              <CardContent className="p-6">
                <h2 className="text-xl font-bold mb-4">Select Pickup Locker</h2>
                <p className="text-sm text-gray-600 mb-4">
                  Choose a convenient locker location to collect your items
                </p>

                <RadioGroup value={selectedLocker} onValueChange={setSelectedLocker}>
                  <div className="space-y-3">
                    {mockLockers.map((locker) => (
                      <div
                        key={locker.id}
                        className={`border rounded-lg p-4 cursor-pointer transition-colors ${
                          selectedLocker === locker.id
                            ? 'border-blue-600 bg-blue-50'
                            : 'border-gray-200 hover:border-gray-300'
                        }`}
                        onClick={() => setSelectedLocker(locker.id)}
                      >
                        <div className="flex items-start">
                          <RadioGroupItem value={locker.id} id={locker.id} className="mt-1" />
                          <div className="ml-3 flex-1">
                            <Label htmlFor={locker.id} className="font-semibold text-base cursor-pointer">
                              {locker.name}
                            </Label>
                            <div className="mt-2 space-y-1">
                              <div className="flex items-center text-sm text-gray-600">
                                <MapPin className="h-4 w-4 mr-2" />
                                {locker.address}, {locker.city}
                              </div>
                              <div className="flex items-center text-sm text-gray-600">
                                <Clock className="h-4 w-4 mr-2" />
                                {locker.hours}
                              </div>
                              {locker.distance && (
                                <div className="text-sm font-medium text-blue-600">
                                  {locker.distance} away
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </RadioGroup>
              </CardContent>
            </Card>
          </div>

          {/* Order Summary */}
          <div className="lg:col-span-1">
            <Card className="sticky top-24">
              <CardContent className="p-6">
                <h2 className="text-xl font-bold mb-4">Order Summary</h2>

                <div className="space-y-3 mb-4">
                  {cart.map((item) => (
                    <div key={item.id} className="flex justify-between text-sm">
                      <span className="text-gray-600">
                        {item.title} x{item.quantity}
                      </span>
                      <span className="font-medium">${item.price * item.quantity}</span>
                    </div>
                  ))}
                </div>

                <div className="border-t pt-3 space-y-2 mb-6">
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600">Subtotal</span>
                    <span className="font-medium">${getCartTotal()}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-gray-600">Service Fee</span>
                    <span className="font-medium">$5</span>
                  </div>
                  <div className="border-t pt-2">
                    <div className="flex justify-between">
                      <span className="font-bold text-lg">Total</span>
                      <span className="font-bold text-lg">${getCartTotal() + 5}</span>
                    </div>
                  </div>
                </div>

                <Button
                  size="lg"
                  className="w-full"
                  onClick={handleCheckout}
                  disabled={!email || !phone}
                >
                  Complete Order
                </Button>

                <p className="text-xs text-gray-500 text-center mt-4">
                  You'll receive an access code to collect your items
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </main>
    </div>
  );
}