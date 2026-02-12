import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { Card, CardContent } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Separator } from '../components/ui/separator';
import { CheckCircle2, MapPin, Clock, Lock, Package, Key } from 'lucide-react';

export function SellerConfirmationPage() {
  const navigate = useNavigate();
  const [listing, setListing] = useState<any>(null);

  useEffect(() => {
    const listingData = sessionStorage.getItem('newListing');
    if (!listingData) {
      navigate('/');
      return;
    }
    setListing(JSON.parse(listingData));
  }, [navigate]);

  if (!listing) {
    return null;
  }

  const listingDate = new Date(listing.date);
  const formattedDate = listingDate.toLocaleDateString('en-US', {
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
          <h1 className="text-3xl font-bold mb-2">Listing Created Successfully!</h1>
          <p className="text-gray-600">
            Your item has been listed. Here's your locker information.
          </p>
        </div>

        {/* Locker Assignment Card */}
        <Card className="mb-6 shadow-lg">
          <CardContent className="p-0">
            {/* Card Header */}
            <div className="bg-gradient-to-r from-purple-600 to-pink-600 text-white p-6 rounded-t-lg">
              <div className="flex items-center justify-center mb-2">
                <Package className="h-6 w-6 mr-2" />
                <h2 className="text-xl font-bold">LOCKER ASSIGNMENT</h2>
              </div>
              <p className="text-center text-sm opacity-90">BumpBox - Secondlife</p>
            </div>

            {/* Card Body */}
            <div className="p-6">
              {/* Listing Info */}
              <div className="mb-6">
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-gray-600">Listing ID:</span>
                  <span className="font-mono font-medium">#{listing.id}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Created:</span>
                  <span className="font-medium">{formattedDate}</span>
                </div>
              </div>

              <Separator className="my-4" />

              {/* Item Details */}
              <div className="mb-6">
                <h3 className="font-bold mb-3">Item Details</h3>
                <div className="bg-gray-50 rounded-lg p-4 space-y-2">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Title:</span>
                    <span className="font-medium">{listing.title}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Category:</span>
                    <span className="font-medium">{listing.category}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Condition:</span>
                    <span className="font-medium">{listing.condition}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Price:</span>
                    <span className="font-medium text-lg">${listing.price}.00</span>
                  </div>
                </div>
              </div>

              <Separator className="my-4" />

              {/* Drop-off Location */}
              <div className="mb-6">
                <h3 className="font-bold mb-3">Drop-off Location</h3>
                <div className="bg-gray-50 rounded-lg p-4">
                  <p className="font-semibold mb-2">{listing.locker.name}</p>
                  <div className="space-y-1 text-sm">
                    <div className="flex items-start text-gray-600">
                      <MapPin className="h-4 w-4 mr-2 mt-0.5 flex-shrink-0" />
                      <span>{listing.locker.address}, {listing.locker.city}</span>
                    </div>
                    <div className="flex items-start text-gray-600">
                      <Clock className="h-4 w-4 mr-2 mt-0.5 flex-shrink-0" />
                      <span>{listing.locker.hours}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Locker ID - Prominent Display */}
              <div className="bg-gradient-to-br from-purple-50 to-pink-50 border-2 border-purple-300 rounded-lg p-6 mb-4">
                <div className="flex items-center justify-center mb-3">
                  <Key className="h-6 w-6 text-purple-600 mr-2" />
                  <h3 className="font-bold text-lg">Assigned Locker ID</h3>
                </div>
                <div className="bg-white rounded-lg p-6 mb-3 shadow-sm">
                  <p className="text-5xl font-mono font-bold text-purple-600 tracking-widest text-center">
                    {listing.lockerId}
                  </p>
                </div>
                <p className="text-sm text-gray-600 text-center">
                  This is your designated locker number
                </p>
              </div>

              {/* Access Code - Prominent Display */}
              <div className="bg-gradient-to-br from-blue-50 to-purple-50 border-2 border-blue-300 rounded-lg p-6 text-center">
                <div className="flex items-center justify-center mb-3">
                  <Lock className="h-6 w-6 text-blue-600 mr-2" />
                  <h3 className="font-bold text-lg">Access Passcode</h3>
                </div>
                <div className="bg-white rounded-lg p-6 mb-3 shadow-sm">
                  <p className="text-5xl font-mono font-bold text-blue-600 tracking-widest">
                    {listing.passcode}
                  </p>
                </div>
                <p className="text-sm text-gray-600">
                  Use this 6-digit code to unlock locker {listing.lockerId} and deposit your item
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
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-purple-100 text-purple-600 font-bold text-sm mr-3 flex-shrink-0">
                  1
                </span>
                <span className="text-sm text-gray-600">
                  Visit the locker location at your convenience
                </span>
              </li>
              <li className="flex items-start">
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-purple-100 text-purple-600 font-bold text-sm mr-3 flex-shrink-0">
                  2
                </span>
                <span className="text-sm text-gray-600">
                  Enter your 6-digit passcode on the touchscreen
                </span>
              </li>
              <li className="flex items-start">
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-purple-100 text-purple-600 font-bold text-sm mr-3 flex-shrink-0">
                  3
                </span>
                <span className="text-sm text-gray-600">
                  Locker {listing.lockerId} will automatically open
                </span>
              </li>
              <li className="flex items-start">
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-purple-100 text-purple-600 font-bold text-sm mr-3 flex-shrink-0">
                  4
                </span>
                <span className="text-sm text-gray-600">
                  Place your item inside, close the door, and it will lock automatically
                </span>
              </li>
              <li className="flex items-start">
                <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-purple-100 text-purple-600 font-bold text-sm mr-3 flex-shrink-0">
                  5
                </span>
                <span className="text-sm text-gray-600">
                  Your listing will go live once the item is confirmed in the locker
                </span>
              </li>
            </ol>
          </CardContent>
        </Card>

        {/* Important Notes */}
        <Card className="mb-6 border-yellow-300 bg-yellow-50">
          <CardContent className="p-6">
            <h3 className="font-bold mb-3 flex items-center">
              <span className="text-yellow-600 mr-2">⚠️</span>
              Important Notes
            </h3>
            <ul className="space-y-2 text-sm text-gray-700">
              <li>• Keep your passcode secure and don't share it with anyone</li>
              <li>• You have 48 hours to deposit your item before the locker assignment expires</li>
              <li>• Make sure your item matches the description and images in your listing</li>
              <li>• Once a buyer purchases your item, you'll receive payment within 2-3 business days</li>
            </ul>
          </CardContent>
        </Card>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row gap-4">
          <Link to="/" className="flex-1">
            <Button variant="outline" className="w-full">
              Back to Home
            </Button>
          </Link>
          <Button 
            className="flex-1" 
            onClick={() => window.print()}
          >
            Print Details
          </Button>
        </div>
      </main>
    </div>
  );
}
