import swaggerUi from 'swagger-ui-express';
import { Router } from 'express';

export const openApiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'Idir Connect & Ikub REST API',
    version: '1.0.0',
    description:
      'Production-grade REST API powering Ethiopian mutual aid associations (Idirs) and rotating savings groups (Ikub). Built with Node.js, Express, TypeScript, PostgreSQL, and Prisma.',
    contact: {
      name: 'Idir Connect Engineering Team',
      email: 'support@idirconnect.et',
    },
  },
  servers: [
    {
      url: '/api/v1',
      description: 'API Version 1',
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'Enter your JWT access token obtained from /auth/login or /auth/register',
      },
    },
    schemas: {
      ErrorResponse: {
        type: 'object',
        properties: {
          success: { type: 'boolean', example: false },
          error: {
            type: 'object',
            properties: {
              code: { type: 'string', example: 'VALIDATION_ERROR' },
              message: { type: 'string', example: 'Validation failed' },
              details: { type: 'array', items: { type: 'object' } },
            },
          },
        },
      },
      User: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
          fullName: { type: 'string', example: 'Abebe Tadesse' },
          phoneNumber: { type: 'string', example: '+251911234567' },
          email: { type: 'string', example: 'abebe@example.com' },
          preferredLanguage: { type: 'string', enum: ['am', 'en', 'om'], example: 'am' },
          status: { type: 'string', example: 'ACTIVE' },
        },
      },
      Idir: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
          name: { type: 'string', example: 'Bole Medhanealem Yebego Adragot Idir' },
          description: { type: 'string', example: 'Community mutual-aid idir' },
          region: { type: 'string', example: 'Addis Ababa' },
          currency: { type: 'string', example: 'ETB' },
          status: { type: 'string', example: 'ACTIVE' },
        },
      },
      Contribution: {
        type: 'object',
        properties: {
          id: { type: 'string', format: 'uuid' },
          amount: { type: 'number', example: 200.0 },
          currency: { type: 'string', example: 'ETB' },
          paymentDate: { type: 'string', format: 'date-time' },
          paymentMethod: { type: 'string', example: 'TELEBIRR' },
          receiptNumber: { type: 'string', example: 'REC-261019-A3F1B2' },
          status: { type: 'string', example: 'CONFIRMED' },
        },
      },
    },
  },
  security: [{ bearerAuth: [] }],
  paths: {
    '/auth/register': {
      post: {
        summary: 'Register a new user account',
        tags: ['Authentication'],
        security: [],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['fullName', 'phoneNumber', 'password'],
                properties: {
                  fullName: { type: 'string', example: 'Abebe Kebede' },
                  phoneNumber: { type: 'string', example: '+251911223344' },
                  password: { type: 'string', example: 'SecurePassword123' },
                  email: { type: 'string', example: 'abebe@example.com' },
                  preferredLanguage: { type: 'string', enum: ['am', 'en', 'om'], default: 'am' },
                },
              },
            },
          },
        },
        responses: {
          201: { description: 'User successfully registered' },
          409: { description: 'User already exists' },
        },
      },
    },
    '/auth/login': {
      post: {
        summary: 'Authenticate user with phone and password',
        tags: ['Authentication'],
        security: [],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['phoneNumber', 'password'],
                properties: {
                  phoneNumber: { type: 'string', example: '+251911223344' },
                  password: { type: 'string', example: 'SecurePassword123' },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Authenticated with access & refresh tokens' },
          401: { description: 'Invalid credentials' },
        },
      },
    },
    '/auth/refresh': {
      post: {
        summary: 'Rotate refresh token and obtain fresh access token',
        tags: ['Authentication'],
        security: [],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['refreshToken'],
                properties: {
                  refreshToken: { type: 'string' },
                },
              },
            },
          },
        },
        responses: {
          200: { description: 'Tokens rotated successfully' },
          401: { description: 'Invalid or revoked refresh token' },
        },
      },
    },
    '/auth/logout': {
      post: {
        summary: 'Revoke refresh token and logout',
        tags: ['Authentication'],
        security: [],
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['refreshToken'],
                properties: { refreshToken: { type: 'string' } },
              },
            },
          },
        },
        responses: {
          200: { description: 'Logged out successfully' },
        },
      },
    },
    '/auth/me': {
      get: {
        summary: 'Get currently authenticated user identity and memberships',
        tags: ['Authentication'],
        responses: {
          200: { description: 'User profile with memberships' },
        },
      },
    },
    '/users/me': {
      get: {
        summary: 'Get current user profile',
        tags: ['Users'],
        responses: { 200: { description: 'Current profile' } },
      },
      patch: {
        summary: 'Update current user profile (language, email)',
        tags: ['Users'],
        responses: { 200: { description: 'Profile updated' } },
      },
    },
    '/idirs': {
      post: {
        summary: 'Create a new Idir (creator becomes Chairperson)',
        tags: ['Idirs'],
        responses: { 201: { description: 'Idir created' } },
      },
      get: {
        summary: 'List accessible Idirs (paginated)',
        tags: ['Idirs'],
        responses: { 200: { description: 'List of Idirs' } },
      },
    },
    '/idirs/{idirId}': {
      get: {
        summary: 'Get Idir details and settings',
        tags: ['Idirs'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Idir details' } },
      },
      patch: {
        summary: 'Update Idir metadata (Chairperson only)',
        tags: ['Idirs'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Idir updated' } },
      },
    },
    '/idirs/{idirId}/members': {
      post: {
        summary: 'Add a member to Idir',
        tags: ['Memberships'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 201: { description: 'Member enrolled' } },
      },
      get: {
        summary: 'List Idir members (paginated)',
        tags: ['Memberships'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Members list' } },
      },
    },
    '/idirs/{idirId}/contributions': {
      post: {
        summary: 'Record member contribution with receipt generation',
        tags: ['Contributions'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 201: { description: 'Contribution recorded' } },
      },
      get: {
        summary: 'List contributions with filters',
        tags: ['Contributions'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Contributions list' } },
      },
    },
    '/idirs/{idirId}/contributions/{contributionId}/reverse': {
      post: {
        summary: 'Reverse an erroneous contribution with documented reason',
        tags: ['Contributions'],
        parameters: [
          { name: 'idirId', in: 'path', required: true, schema: { type: 'string' } },
          { name: 'contributionId', in: 'path', required: true, schema: { type: 'string' } },
        ],
        responses: { 200: { description: 'Contribution reversed' } },
      },
    },
    '/idirs/{idirId}/expenses': {
      post: {
        summary: 'Submit an operating expense for approval',
        tags: ['Expenses'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 201: { description: 'Expense submitted' } },
      },
      get: {
        summary: 'List expenses',
        tags: ['Expenses'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Expenses list' } },
      },
    },
    '/idirs/{idirId}/assistance/cases': {
      post: {
        summary: 'Open a funeral or emergency assistance case',
        tags: ['Assistance'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 201: { description: 'Case created' } },
      },
      get: {
        summary: 'List assistance cases (confidentiality enforced)',
        tags: ['Assistance'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Cases list' } },
      },
    },
    '/idirs/{idirId}/ikub/groups': {
      post: {
        summary: 'Create a new Ikub rotating savings group',
        tags: ['Ikub'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 201: { description: 'Ikub group created' } },
      },
      get: {
        summary: 'List Ikub groups inside this Idir',
        tags: ['Ikub'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Ikub groups list' } },
      },
    },
    '/idirs/{idirId}/ikub/groups/{groupId}/payouts': {
      post: {
        summary: 'Award and record round payout (duplicate payouts prevented)',
        tags: ['Ikub'],
        parameters: [
          { name: 'idirId', in: 'path', required: true, schema: { type: 'string' } },
          { name: 'groupId', in: 'path', required: true, schema: { type: 'string' } },
        ],
        responses: { 201: { description: 'Payout confirmed' } },
      },
    },
    '/idirs/{idirId}/reports/finances': {
      get: {
        summary: 'Generate segregated Idir balance and Ikub savings pool statement',
        tags: ['Reports'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Separated financial statement' } },
      },
    },
    '/idirs/{idirId}/audit': {
      get: {
        summary: 'Access immutable audit trail (Chairperson & Auditor only)',
        tags: ['Audit'],
        parameters: [{ name: 'idirId', in: 'path', required: true, schema: { type: 'string' } }],
        responses: { 200: { description: 'Audit logs list' } },
      },
    },
  },
};

export const docsRouter = Router();
docsRouter.use('/', swaggerUi.serve, swaggerUi.setup(openApiSpec));
