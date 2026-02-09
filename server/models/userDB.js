const db = require('../dbConnection');
const Joi = require('joi');

const users = {
    validateAccess: (id = 'params.userId') => {
        return async (req, res, next) => {
            try {
                const query = `SELECT id, role FROM users WHERE id = ?`;
                const [rows] = await db.execute(query, [req.params.userId]);
                if (rows.length === 0) {
                    throw new Error({ message: 'User not found', status: 404 });
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
                id: Joi.number().integer().required(),
                name: Joi.string().min(1).max(100).required(),
                email: Joi.string().email().required()
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