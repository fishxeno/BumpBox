export function getAPIBaseURL() {
    // In a real application, you might want to determine this dynamically
    return 'http://localhost:3000'; // Adjust the port if your server runs on a different one
}

export async function fetchProducts() {
    const response = await fetch(`${getAPIBaseURL()}/products`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json',
        },
    });
    const data = await response.json();
    return data;
}

export async function fetchProductById(productId: string) {
    const response = await fetch(`${getAPIBaseURL()}/products/${productId}`, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json',
        },
    });
    const data = await response.json();
    return data;
}

export async function createProduct(productData: { name: string; price: number; description?: string }) {
    const response = await fetch(`${getAPIBaseURL()}/products`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(productData),
    });
    const data = await response.json();
    return data;
}

export async function updateProduct(productId: string, updateData: { name?: string; price?: number; description?: string }) {
    const response = await fetch(`${getAPIBaseURL()}/products/${productId}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(updateData),
    });
    const data = await response.json();
    return data;
}

export async function deleteProduct(productId: string) {
    const response = await fetch(`${getAPIBaseURL()}/products/${productId}`, {
        method: 'DELETE',
        headers: {
            'Content-Type': 'application/json',
        },
    });
    const data = await response.json();
    return data;
}
