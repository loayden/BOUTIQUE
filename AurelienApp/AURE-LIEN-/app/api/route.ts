import { NextResponse } from 'next/server'
import { databaseHealthSummary } from '../../lib/backend'

export const dynamic = 'force-dynamic'

export async function GET() {
  const database = await databaseHealthSummary()

  return NextResponse.json({
    ok: true,
    service: 'BOUTIQUE API',
    storage: database.storage,
    database,
    endpoints: {
      products: '/api/products',
      uploads: '/api/uploads/product-image',
      signin: '/api/auth/signin',
      signup: '/api/auth/signup',
    },
  })
}
