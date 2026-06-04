import Image from 'next/image'
import { commerceImageObjectPosition, getCatalog } from '../lib/backend'

export const dynamic = 'force-dynamic'

const currency = new Intl.NumberFormat('en-EG', {
  style: 'currency',
  currency: 'EGP',
  maximumFractionDigits: 0,
})

export default async function Home() {
  const products = await getCatalog()
  const featuredProducts = products
    .filter((product) => product.featured || product.isAvailable !== false)
    .slice(0, 6)
  const hero = featuredProducts[0] ?? products[0]

  return (
    <main className="min-h-screen bg-background text-foreground">
      <section className="container-fluid grid min-h-[80dvh] items-center gap-10 py-10 md:grid-cols-[1fr_0.88fr] md:py-16">
        <div className="max-w-2xl">
          <p className="text-xs font-semibold uppercase tracking-[0.32em] text-accent">
            BOUTIQUE
          </p>
          <h1 className="mt-5 font-serif text-4xl leading-tight tracking-normal text-foreground sm:text-5xl md:text-6xl">
            Warm tailoring, live catalog, fast checkout.
          </h1>
          <p className="mt-5 max-w-xl text-base leading-8 text-[var(--foreground-soft)] sm:text-lg">
            Discover curated menswear, reserve available pieces, and place real orders from the same catalog that powers the mobile app.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <a
              className="inline-flex min-h-11 items-center justify-center rounded-md bg-gradient-to-r from-[#4C3A26] to-[#7D592B] px-5 text-sm font-semibold text-[#FFF9EF] shadow-sm"
              href="/api/products"
            >
              View live catalog
            </a>
            <a
              className="inline-flex min-h-11 items-center justify-center rounded-md border border-[var(--border-warm)] bg-white/55 px-5 text-sm font-semibold text-foreground"
              href="/api"
            >
              API health
            </a>
          </div>
        </div>

        {hero ? (
          <div className="editorial-hero-panel">
            <div className="editorial-hero-frame">
              <Image
                src={hero.images[0] ?? '/uploads/main.jpg'}
                alt={hero.name}
                fill
                priority
                sizes="(min-width: 1024px) 42vw, 92vw"
                className="editorial-hero-image"
                style={{ objectPosition: commerceImageObjectPosition(hero) }}
              />
              <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-[#3D3025]/78 via-[#3D3025]/22 to-transparent p-5">
                <p className="text-sm font-semibold text-[#FFF9EF]">{hero.name}</p>
                <p className="mt-1 text-sm text-[#FFF9EF]/82">{currency.format(hero.price)}</p>
              </div>
            </div>
          </div>
        ) : null}
      </section>

      <section className="container-fluid pb-14">
        <div className="mb-5 flex items-end justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.28em] text-accent">
              Live edits
            </p>
            <h2 className="mt-2 font-serif text-2xl text-foreground">
              Ready-to-shop pieces
            </h2>
          </div>
          <p className="text-sm text-[var(--foreground-soft)]">
            {products.length} active products
          </p>
        </div>

        {featuredProducts.length ? (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {featuredProducts.map((product, index) => (
              <article
                className="product-card"
                key={product._id}
              >
                <div className="product-media-frame">
                  <Image
                    src={product.images[0] ?? '/uploads/main.jpg'}
                    alt={product.name}
                    fill
                    sizes="(min-width: 1024px) 30vw, (min-width: 640px) 45vw, 92vw"
                    className="product-media-image"
                    priority={index === 0}
                    style={{ objectPosition: commerceImageObjectPosition(product) }}
                  />
                </div>
                <div className="p-4">
                  <p className="text-sm font-semibold text-foreground">{product.name}</p>
                  <p className="mt-1 text-sm text-[var(--foreground-soft)]">
                    {currency.format(product.price)}
                  </p>
                </div>
              </article>
            ))}
          </div>
        ) : (
          <div className="rounded-lg border border-[var(--border-warm)] bg-white/60 p-6 text-sm text-[var(--foreground-soft)]">
            The live catalog is empty. Add products from the admin app to publish them here.
          </div>
        )}
      </section>
    </main>
  )
}
