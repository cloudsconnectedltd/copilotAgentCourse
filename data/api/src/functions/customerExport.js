import { app } from '@azure/functions';
import { customerExport } from '../lib/handlers.js';

// GET /api/customers?region=  Legacy unbounded export, referenced only by openapi-broken.yaml.
app.http('customers', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'customers',
  handler: (request, context) => customerExport(request, context),
});
