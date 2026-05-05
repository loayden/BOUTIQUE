import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET() {
  return NextResponse.json({
    ok: true,
    service: 'BOUTIQUE API',
    storage: process.env.AURELIEN_MONGODB_URI?.trim() ? 'mongodb' : 'local-json',
    endpoints: {
      products: '/api/products',
      uploads: '/api/uploads/product-image',
      signin: '/api/auth/signin',
      signup: '/api/auth/signup',
    },
  })
}
