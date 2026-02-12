import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { Card, CardContent } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Separator } from '../components/ui/separator';
import { CheckCircle2, MapPin, Clock, Lock, Receipt } from 'lucide-react';

export function ReceiptPage() {
  const navigate = useNavigate();
  const [order, setOrder] = useState<any>(null);

  useEffect(() => {
    const orderData = sessionStorage.getItem('lastOrder');
    if (!orderData) {
      navigate('/');
      return;
    }
    setOrder(JSON.parse(orderData));
  }, [navigate]);

  if (!order) {
    return null;
  }

  const orderDate = new Date(order.date);
  const formattedDate = orderDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8">
          <Link to="/" className="flex items-center space-x-2">
            <h1 className="text-2xl font-bold text-gray-900">BumpBox - Secondlife</h1>
          </Link>
        </div>
      </header>

      <main className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        {/* Success Message */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-green-100 rounded-full mb-4">
            <CheckCircle2 className="h-8 w-8 text-green-600" />
          </div>
          <h1 className="text-3xl font-bold mb-2">Purchase Complete!</h1>
          <p className="text-gray-600">
            Thank you for your purchase. Your receipt is shown below.
          </p>
        </div>

        {/* Receipt Card */}
        <Card className="mb-6 shadow-lg">
          <CardContent className="p-0">
            {/* Receipt Header */}
            <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white p-6 rounded-t-lg">
              <div className="flex items-center justify-center mb-2">
                <Receipt className="h-6 w-6 mr-2" />
                <h2 className="text-xl font-bold">RECEIPT</h2>
              </div>
              <p className="text-center text-sm opacity-90">BumpBox - Secondlife</p>
            </div>

            {/* Receipt Body */}
            <div className="p-6">
              {/* Order Info */}
              <div className="mb-6">
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-gray-600">Order Number:</span>
                  <span className="font-mono font-medium">#{order.id}</span>
                </div>
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-gray-600">Date:</span>
                  <span className="font-medium">{formattedDate}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Email:</span>
                  <span className="font-medium">{order.email}</span>
                </div>
              </div>

              <Separator className="my-4" />

              {/* Items */}
              <div className="mb-6">
                <h3 className="font-bold mb-3">Items Purchased</h3>
                <div className="space-y-2">
                  {order.items.map((item: any) => (
                    <div key={item.id} className="flex justify-between text-sm">
                      <div className="flex-1">
                        <p className="font-medium">{item.title}</p>
                        <p className="text-gray-600">
                          {item.condition} • Qty: {item.quantity}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="font-medium">${item.price * item.quantity}.00</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <Separator className="my-4" />

              {/* Totals */}
              <div className="space-y-2 mb-6">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Subtotal</span>
                  <span className="font-medium">${order.total - 5}.00</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Service Fee</span>
                  <span className="font-medium">$5.00</span>
                </div>
                <Separator className="my-2" />
                <div className="flex justify-between">
                  <span className="font-bold text-lg">Total Paid</span>
                  <span className="font-bold text-lg">${order.total}.00</span>
                </div>
              </div>

              <Separator className="my-4" />

              {/* Pickup Location */}
              <div className="mb-6">
                <h3 className="font-bold mb-3">Pickup Location</h3>
                <div className="bg-gray-50 rounded-lg p-4">
                  <p className="font-semibold mb-2">{order.locker.name}</p>
                  <div className="space-y-1 text-sm">
                    <div className="flex items-start text-gray-600">
                      <MapPin className="h-4 w-4 mr-2 mt-0.5 flex-shrink-0" />
                      <span>{order.locker.address}, {order.locker.city}</span>
                    </div>
                    <div className="flex items-start text-gray-600">
                      <Clock className="h-4 w-4 mr-2 mt-0.5 flex-shrink-0" />
                      <span>{order.locker.hours}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Access Code - Prominent Display */}
              <div className="bg-gradient-to-br from-blue-50 to-purple-50 border-2 border-blue-300 rounded-lg p-6 text-center">
                <div className="flex items-center justify-center mb-3">
                  <Lock className="h-6 w-6 text-blue-600 mr-2" />
                  <h3 className="font-bold text-lg">Locker Access Code</h3>
                </div>
                <div className="bg-white rounded-lg p-6 mb-3 shadow-sm">
                  <p className="text-5xl font-mono font-bold text-blue-600 tracking-widest">
                    {order.accessCode}
                  </p>
                </div>
                <p className="text-sm text-gray-600">
                  Enter this 6-digit code at the locker to collect your items
                </p>
                <p className="text-xs text-gray-500 mt-2">
                  Code also sent to {order.email} and {order.phone}
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Instructions */}
        <Card className="mb-6">
          <CardContent className="p-6">
            <h3 className="font-bold mb-4">Next Steps</h3>
            <ol className="space-y-3">
              <li className="flex items-start">
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-600 font-bold text-sm mr-3 flex-shrink-0">
                  1
                </span>
                <span className="text-sm text-gray-600">
                  Your items will be prepared and placed in the locker within 24-48 hours
                </span>
              </li>
              <li className="flex items-start">
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-600 font-bold text-sm mr-3 flex-shrink-0">
                  2
                </span>
                <span className="text-sm text-gray-600">
                  You'll receive a notification when your items are ready for pickup
                </span>
              </li>
              <li className="flex items-start">
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-600 font-bold text-sm mr-3 flex-shrink-0">
                  3
                </span>
                <span className="text-sm text-gray-600">
                  Visit the locker location and enter your 6-digit code on the touchscreen
                </span>
              </li>
              <li className="flex items-start">
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-blue-100 text-blue-600 font-bold text-sm mr-3 flex-shrink-0">
                  4
                </span>
                <span className="text-sm text-gray-600">
                  The locker containing your items will automatically open
                </span>
              </li>
            </ol>
          </CardContent>
        </Card>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row gap-4">
          <Link to="/shop" className="flex-1">
            <Button variant="outline" className="w-full">
              Continue Shopping
            </Button>
          </Link>
          <Button 
            className="flex-1" 
            onClick={() => window.print()}
          >
            Print Receipt
          </Button>
        </div>
      </main>
    </div>
  );
}
