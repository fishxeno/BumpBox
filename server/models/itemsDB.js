import db from '../dbConnection.js';
import Joi from 'joi';

const items = {
    validateAccess: (id = 'params.itemId') => {
        return async (req, res, next) => {
            try {
                const query = `SELECT id, role FROM items WHERE id = ?`;
                const [rows] = await db.execute(query, [req.params.itemId]);
                if (rows.length === 0) {
                    throw new Error({ message: 'Item not found', status: 404 });
                }
            } catch (error) {
                console.error('Access validation error:', error);
                return res.status(500).json({ error: 'Internal server error' });
            }
        };
    },

    validateData: async (req, res, next) => {
        try {
            const schema = Joi.object({
                itemId: Joi.number().integer().required(),
                userId: Joi.number().integer().required(),
                item_name: Joi.string().min(1).max(255).required(),
                price: Joi.number().precision(2).required(),
                description: Joi.string().max(255).optional(),
            });

            const value = await schema.validateAsync(req.body);
            res.local.data = value;
            next();
        } catch (error) {
            console.error('Validation error:', error);
            return res.status(400).json({ error: 'Invalid data format' });
        }
    },

    getItemStatusById: async (itemId) => {
        try {
            const query = `SELECT * FROM items WHERE id = ?`;
            const [rows] = await db.execute(query, [itemId]);
            if (rows.length === 0) {
                throw new Error('404', 'Item not found');
            }
            if (rows[0].status == 'true') {
                res.status(200).json({ status: true, message: 'Item is sold' });
            }
            res.status(200).json({ status: false, message: 'Item is not sold' });
        } catch (error) {
            console.error('Get item error:', error.stack);
            throw new Error('500', 'Error fetching item');
        }
    },
    createNewItem: async (itemData) => {
        try {
            const query = `INSERT INTO items (userId, item_name, price, description) VALUES (?, ?, ?, ?)`;
            const [result] = await db.execute(query, [
                itemData.userId,
                itemData.item_name,
                itemData.price,
                itemData.description
            ]);
            return result;
        } catch (error) {
            console.error('Create new item error:', error.stack);
            throw new Error('500', 'Error creating new item');
        }
    },
};

export default items;