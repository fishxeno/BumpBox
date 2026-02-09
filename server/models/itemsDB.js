const db = require('../dbConnection');
const Joi = require('joi');

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
                itemname: Joi.string().min(1).max(255).required(),
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
}