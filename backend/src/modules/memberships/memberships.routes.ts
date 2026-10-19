import { Router } from 'express';
import { membershipsController } from './memberships.controller.js';
import { authenticate } from '../../middleware/authenticate.js';
import { requireIdirRole } from '../../middleware/authorize.js';
import { validate } from '../../middleware/validate.js';
import {
  addMemberSchema,
  updateMemberSchema,
  queryMembersSchema,
} from './memberships.validation.js';

const router = Router({ mergeParams: true });

router.use(authenticate);

router.post(
  '/',
  requireIdirRole(['CHAIRPERSON', 'TREASURER', 'SECRETARY']),
  validate({ body: addMemberSchema }),
  membershipsController.addMember
);

router.get(
  '/',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  validate({ query: queryMembersSchema }),
  membershipsController.listMembers
);

router.get(
  '/:membershipId',
  requireIdirRole([
    'CHAIRPERSON',
    'TREASURER',
    'SECRETARY',
    'COMMITTEE',
    'AUDITOR',
    'MEMBER',
  ]),
  membershipsController.getMemberById
);

router.patch(
  '/:membershipId',
  requireIdirRole(['CHAIRPERSON', 'SECRETARY']),
  validate({ body: updateMemberSchema }),
  membershipsController.updateMember
);

router.post(
  '/:membershipId/deactivate',
  requireIdirRole(['CHAIRPERSON']),
  membershipsController.deactivateMember
);

export const membershipRoutes = router;
