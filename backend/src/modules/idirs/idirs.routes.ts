import { Router } from 'express';
import { idirsController } from './idirs.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  createIdirSchema,
  updateIdirSchema,
  updateSettingsSchema,
  queryIdirsSchema,
} from './idirs.validation.js';

const router = Router();

router.use(authenticate);

router.post('/', validate({ body: createIdirSchema }), idirsController.createIdir);
router.get('/', validate({ query: queryIdirsSchema }), idirsController.listIdirs);
router.get('/:idirId', idirsController.getIdirById);
router.patch(
  '/:idirId',
  requireIdirRole(['CHAIRPERSON']),
  validate({ body: updateIdirSchema }),
  idirsController.updateIdir
);
router.patch(
  '/:idirId/settings',
  requireIdirRole(['CHAIRPERSON']),
  validate({ body: updateSettingsSchema }),
  idirsController.updateSettings
);

export const idirRoutes = router;
