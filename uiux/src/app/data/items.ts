export interface Item {
  id: string;
  title: string;
  price: number;
  condition: 'Like New' | 'Good' | 'Fair' | 'Well Used';
  description: string;
  category: string;
  imageUrl: string;
  sellerId: string;
  sellerName: string;
  availability: 'Available' | 'Pending' | 'Sold';
}

export interface Locker {
  id: string;
  name: string;
  address: string;
  city: string;
  hours: string;
  distance?: string;
}

export interface CartItem extends Item {
  quantity: number;
}

export interface Order {
  id: string;
  items: CartItem[];
  total: number;
  locker: Locker;
  date: string;
  status: 'Processing' | 'Ready for Pickup' | 'Collected';
  accessCode?: string;
}

export const mockItems: Item[] = [
  {
    id: '1',
    title: 'Vintage Film Camera',
    price: 85,
    condition: 'Good',
    description: 'Classic 35mm film camera in working condition. Perfect for film photography enthusiasts. Includes original leather case.',
    category: 'Electronics',
    imageUrl: 'https://images.unsplash.com/photo-1495121553079-4c61bcce1894?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx2aW50YWdlJTIwY2FtZXJhfGVufDF8fHx8MTc3MDgyMjY5NXww&ixlib=rb-4.1.0&q=80&w=1080',
    sellerId: 's1',
    sellerName: 'PhotoCollector',
    availability: 'Available',
  },
  {
    id: '2',
    title: 'City Bicycle',
    price: 120,
    condition: 'Like New',
    description: 'Barely used city bike with comfortable seat and basket. Great for commuting around town.',
    category: 'Sports',
    imageUrl: 'https://images.unsplash.com/photo-1751048478961-f11df7b92e2f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx1c2VkJTIwYmljeWNsZXxlbnwxfHx8fDE3NzA4NjA5NDd8MA&ixlib=rb-4.1.0&q=80&w=1080',
    sellerId: 's2',
    sellerName: 'UrbanCyclist',
    availability: 'Available',
  },
  {
    id: '3',
    title: 'Leather Jacket',
    price: 65,
    condition: 'Good',
    description: 'Stylish brown leather jacket with minimal wear. Size M. Timeless vintage look.',
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1606163015906-ad3c68002dcb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx2aW50YWdlJTIwbGVhdGhlciUyMGphY2tldHxlbnwxfHx8fDE3NzA3OTk0ODV8MA&ixlib=rb-4.1.0&q=80&w=1080',
    sellerId: 's3',
    sellerName: 'FashionFinds',
    availability: 'Available',
  },
  {
    id: '4',
    title: 'PlayStation 4 Console',
    price: 180,
    condition: 'Good',
    description: 'PS4 console with 500GB storage. Includes one controller and power cable. Fully tested and working.',
    category: 'Electronics',
    imageUrl: 'https://images.unsplash.com/photo-1604846887565-640d2f52d564?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxnYW1pbmclMjBjb25zb2xlfGVufDF8fHx8MTc3MDgyOTg5Nnww&ixlib=rb-4.1.0&q=80&w=1080',
    sellerId: 's4',
    sellerName: 'GamerZone',
    availability: 'Available',
  },
  {
    id: '5',
    title: 'Acoustic Guitar',
    price: 95,
    condition: 'Fair',
    description: 'Yamaha acoustic guitar with warm tone. Has a few scratches but plays beautifully. Great for beginners.',
    category: 'Music',
    imageUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxhY291c3RpYyUyMGd1aXRhcnxlbnwxfHx8fDE3NzA4NjA5NDh8MA&ixlib=rb-4.1.0&q=80&w=1080',
    sellerId: 's5',
    sellerName: 'MusicLover',
    availability: 'Available',
  },
  {
    id: '6',
    title: 'Mid-Century Armchair',
    price: 150,
    condition: 'Good',
    description: 'Beautiful mid-century modern armchair. Reupholstered in teal fabric. Solid wood frame.',
    category: 'Furniture',
    imageUrl: 'https://images.unsplash.com/photo-1768203634842-ece3bb915cc1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx2aW50YWdlJTIwZnVybml0dXJlJTIwY2hhaXJ8ZW58MXx8fHwxNzcwODYwOTQ4fDA&ixlib=rb-4.1.0&q=80&w=1080',
    sellerId: 's6',
    sellerName: 'VintageHome',
    availability: 'Available',
  },
  {
    id: '7',
    title: 'Vintage Wristwatch',
    price: 45,
    condition: 'Good',
    description: 'Classic automatic watch with leather strap. Keeps good time. Minor surface scratches on case.',
    category: 'Accessories',
    imageUrl: 'https://images.unsplash.com/photo-1677445166019-4fa91a090e49?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx2aW50YWdlJTIwd2F0Y2h8ZW58MXx8fHwxNzcwODYwOTQ4fDA&ixlib=rb-4.1.0&q=80&w=1080',
    sellerId: 's7',
    sellerName: 'TimeKeeper',
    availability: 'Available',
  },
  {
    id: '8',
    title: 'Nike Air Max Sneakers',
    price: 55,
    condition: 'Like New',
    description: 'Gently used Nike Air Max in excellent condition. Size 10. Only worn a handful of times.',
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1656944227480-98180d2a5155?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxzbmVha2VycyUyMHNob2VzfGVufDF8fHx8MTc3MDgyMTkzN3ww&ixlib=rb-4.1.0&q=80&w=1080',
    sellerId: 's8',
    sellerName: 'SneakerHead',
    availability: 'Available',
  },
];

export const mockLockers: Locker[] = [
  {
    id: 'l1',
    name: 'Downtown Hub',
    address: '123 Main Street',
    city: 'Downtown',
    hours: '24/7',
    distance: '0.5 miles',
  },
  {
    id: 'l2',
    name: 'Westside Mall',
    address: '456 West Avenue',
    city: 'Westside',
    hours: '9 AM - 9 PM',
    distance: '1.2 miles',
  },
  {
    id: 'l3',
    name: 'Central Station',
    address: '789 Station Plaza',
    city: 'Central',
    hours: '24/7',
    distance: '2.1 miles',
  },
  {
    id: 'l4',
    name: 'East Market',
    address: '321 Market Road',
    city: 'Eastside',
    hours: '8 AM - 10 PM',
    distance: '3.5 miles',
  },
];
