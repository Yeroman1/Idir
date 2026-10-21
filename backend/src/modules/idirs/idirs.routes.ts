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
import { createDraftIdirSchema } from './create-draft.validation.js';
import { createDraftIdirController } from './create-draft.controller.js';

const router = Router();

router.use(authenticate);

router.post('/', validate({ body: createDraftIdirSchema }), createDraftIdirController.handle);
router.post('/draft', validate({ body: createDraftIdirSchema }), createDraftIdirController.handle);
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
