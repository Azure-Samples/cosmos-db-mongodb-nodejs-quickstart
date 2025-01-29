export type Emit = (message: string) => void;

export interface Product {
    id: string;
    category: string;
    name: string;
    quantity: number;
    price: number;
    clearance: boolean;
}