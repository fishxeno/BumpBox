import { useState } from 'react';
import { Link, useNavigate } from 'react-router';
import { Button } from '../components/ui/button';
import { Card, CardContent } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Textarea } from '../components/ui/textarea';
import { RadioGroup, RadioGroupItem } from '../components/ui/radio-group';
import { ArrowLeft, Upload, X } from 'lucide-react';
import { mockLockers } from '../data/items';

export function CreateListingPage() {
  const navigate = useNavigate();
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('');
  const [price, setPrice] = useState('');
  const [condition, setCondition] = useState('Good');
  const [description, setDescription] = useState('');
  const [selectedLocker, setSelectedLocker] = useState(mockLockers[0].id);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string>('');
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [videoPreview, setVideoPreview] = useState<string>('');

  const conditions = ['Like New', 'Excellent', 'Good', 'Fair', 'Used'];

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setImageFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setImagePreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleVideoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setVideoFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setVideoPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    // Generate locker ID and passcode
    const lockerId = `L${Math.floor(1000 + Math.random() * 9000)}`;
    const passcode = Math.floor(100000 + Math.random() * 900000).toString();
    const selectedLockerData = mockLockers.find((l) => l.id === selectedLocker);

    // Store listing info
    const listing = {
      id: Date.now().toString(),
      title,
      category,
      price: parseFloat(price),
      condition,
      description,
      lockerId,
      passcode,
      locker: selectedLockerData,
      date: new Date().toISOString(),
    };

    sessionStorage.setItem('newListing', JSON.stringify(listing));
    navigate('/seller/confirmation');
  };

  const isFormValid = title && category && price && description && imageFile && videoFile;

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
        <Link to="/">
          <Button variant="ghost" className="mb-6">
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back to Home
          </Button>
        </Link>

        <h1 className="text-3xl font-bold mb-2">Create New Listing</h1>
        <p className="text-gray-600 mb-8">Fill in the details to list your item for sale</p>

        <form onSubmit={handleSubmit}>
          <div className="space-y-6">
            {/* Basic Information */}
            <Card>
              <CardContent className="p-6">
                <h2 className="text-xl font-bold mb-4">Item Details</h2>
                <div className="space-y-4">
                  <div>
                    <Label htmlFor="title">Item Title *</Label>
                    <Input
                      id="title"
                      placeholder="e.g., Vintage Leather Jacket"
                      value={title}
                      onChange={(e) => setTitle(e.target.value)}
                      required
                    />
                  </div>

                  <div>
                    <Label htmlFor="category">Category *</Label>
                    <Input
                      id="category"
                      placeholder="e.g., Clothing, Electronics, Furniture"
                      value={category}
                      onChange={(e) => setCategory(e.target.value)}
                      required
                    />
                  </div>

                  <div>
                    <Label htmlFor="price">Price (USD) *</Label>
                    <Input
                      id="price"
                      type="number"
                      placeholder="0.00"
                      min="0"
                      step="0.01"
                      value={price}
                      onChange={(e) => setPrice(e.target.value)}
                      required
                    />
                  </div>

                  <div>
                    <Label className="mb-3 block">Condition *</Label>
                    <RadioGroup value={condition} onValueChange={setCondition}>
                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                        {conditions.map((cond) => (
                          <div
                            key={cond}
                            className={`border rounded-lg p-3 cursor-pointer transition-colors ${
                              condition === cond
                                ? 'border-blue-600 bg-blue-50'
                                : 'border-gray-200 hover:border-gray-300'
                            }`}
                            onClick={() => setCondition(cond)}
                          >
                            <div className="flex items-center">
                              <RadioGroupItem value={cond} id={cond} />
                              <Label htmlFor={cond} className="ml-2 cursor-pointer">
                                {cond}
                              </Label>
                            </div>
                          </div>
                        ))}
                      </div>
                    </RadioGroup>
                  </div>

                  <div>
                    <Label htmlFor="description">Description *</Label>
                    <Textarea
                      id="description"
                      placeholder="Describe your item, its condition, any defects, size, color, etc."
                      rows={5}
                      value={description}
                      onChange={(e) => setDescription(e.target.value)}
                      required
                    />
                    <p className="text-sm text-gray-500 mt-1">
                      Provide detailed information to help buyers make an informed decision
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Media Upload */}
            <Card>
              <CardContent className="p-6">
                <h2 className="text-xl font-bold mb-4">Media</h2>
                <div className="space-y-6">
                  {/* Image Upload */}
                  <div>
                    <Label className="mb-2 block">Item Image *</Label>
                    {imagePreview ? (
                      <div className="relative">
                        <img
                          src={imagePreview}
                          alt="Preview"
                          className="w-full h-64 object-cover rounded-lg"
                        />
                        <Button
                          type="button"
                          variant="destructive"
                          size="sm"
                          className="absolute top-2 right-2"
                          onClick={() => {
                            setImageFile(null);
                            setImagePreview('');
                          }}
                        >
                          <X className="h-4 w-4" />
                        </Button>
                      </div>
                    ) : (
                      <label className="flex flex-col items-center justify-center w-full h-64 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:bg-gray-50 transition-colors">
                        <div className="flex flex-col items-center justify-center pt-5 pb-6">
                          <Upload className="h-10 w-10 text-gray-400 mb-3" />
                          <p className="mb-2 text-sm text-gray-600">
                            <span className="font-semibold">Click to upload</span> or drag and drop
                          </p>
                          <p className="text-xs text-gray-500">PNG, JPG, JPEG (MAX. 10MB)</p>
                        </div>
                        <input
                          type="file"
                          className="hidden"
                          accept="image/*"
                          onChange={handleImageChange}
                          required
                        />
                      </label>
                    )}
                  </div>

                  {/* Video Upload */}
                  <div>
                    <Label className="mb-2 block">Item Video *</Label>
                    {videoPreview ? (
                      <div className="relative">
                        <video
                          src={videoPreview}
                          controls
                          className="w-full h-64 object-cover rounded-lg"
                        />
                        <Button
                          type="button"
                          variant="destructive"
                          size="sm"
                          className="absolute top-2 right-2"
                          onClick={() => {
                            setVideoFile(null);
                            setVideoPreview('');
                          }}
                        >
                          <X className="h-4 w-4" />
                        </Button>
                      </div>
                    ) : (
                      <label className="flex flex-col items-center justify-center w-full h-64 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:bg-gray-50 transition-colors">
                        <div className="flex flex-col items-center justify-center pt-5 pb-6">
                          <Upload className="h-10 w-10 text-gray-400 mb-3" />
                          <p className="mb-2 text-sm text-gray-600">
                            <span className="font-semibold">Click to upload</span> or drag and drop
                          </p>
                          <p className="text-xs text-gray-500">MP4, MOV, AVI (MAX. 50MB)</p>
                        </div>
                        <input
                          type="file"
                          className="hidden"
                          accept="video/*"
                          onChange={handleVideoChange}
                          required
                        />
                      </label>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Locker Selection */}
            <Card>
              <CardContent className="p-6">
                <h2 className="text-xl font-bold mb-4">Locker Location</h2>
                <p className="text-sm text-gray-600 mb-4">
                  Choose where you'll drop off your item
                </p>

                <RadioGroup value={selectedLocker} onValueChange={setSelectedLocker}>
                  <div className="space-y-3">
                    {mockLockers.map((locker) => (
                      <div
                        key={locker.id}
                        className={`border rounded-lg p-4 cursor-pointer transition-colors ${
                          selectedLocker === locker.id
                            ? 'border-purple-600 bg-purple-50'
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
                            <p className="text-sm text-gray-600 mt-1">
                              {locker.address}, {locker.city}
                            </p>
                            <p className="text-sm text-gray-600">{locker.hours}</p>
                            {locker.distance && (
                              <div className="text-sm font-medium text-purple-600 mt-1">
                                {locker.distance} away
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </RadioGroup>
              </CardContent>
            </Card>

            {/* Submit Button */}
            <div className="flex gap-4">
              <Link to="/" className="flex-1">
                <Button type="button" variant="outline" className="w-full" size="lg">
                  Cancel
                </Button>
              </Link>
              <Button
                type="submit"
                className="flex-1"
                size="lg"
                disabled={!isFormValid}
              >
                Create Listing
              </Button>
            </div>
          </div>
        </form>
      </main>
    </div>
  );
}
