import { app } from '@azure/functions';
import { crewDispatch } from '../lib/handlers.js';

// POST /api/crew-dispatch  body: { outageId, crewId, priority, notes }
app.http('crew-dispatch', {
  methods: ['POST'],
  authLevel: 'anonymous',
  route: 'crew-dispatch',
  handler: (request, context) => crewDispatch(request, context),
});
