import { Router } from 'express';
import { usersController } from './users.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { validate } from '../../middleware/validate.js';
import { updateProfileSchema } from './users.validation.js';

const router = Router();

router.use(authenticate);

// Profile endpoints for current user
router.get('/me', usersController.getMe);
router.patch('/me', validate({ body: updateProfileSchema }), usersController.updateMe);
router.put('/me', validate({ body: updateProfileSchema }), usersController.updateMe);

// Profile endpoints by userId (supports :userId matching authenticated user)
router.get('/:userId', usersController.getUserById);
router.patch('/:userId', validate({ body: updateProfileSchema }), usersController.updateUserById);
router.put('/:userId', validate({ body: updateProfileSchema }), usersController.updateUserById);

export const usersRoutes = router;
