import { app } from '@azure/functions';
import { customerLookup } from '../lib/handlers.js';

// GET /api/customer-lookup?accountNumber=&lastName=&postalCode=&pageSize=&page=
app.http('customer-lookup', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'customer-lookup',
  handler: (request, context) => customerLookup(request, context),
});
