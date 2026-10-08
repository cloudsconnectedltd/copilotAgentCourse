import { app } from '@azure/functions';
import { outageStatus } from '../lib/handlers.js';

// GET /api/outage-status?region=&outageId=&includeRestored=&pageSize=&delayMs=
// authLevel is anonymous because the API does its own auth (see src/lib/auth.js, AUTH_MODE).
app.http('outage-status', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'outage-status',
  handler: (request, context) => outageStatus(request, context),
});
