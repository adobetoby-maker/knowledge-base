# SEO: E-commerce SEO

## Overview

E-commerce SEO covers: product page optimization, category page strategy, faceted navigation handling, schema markup for products, and avoiding duplicate content from product variants. The highest-impact areas: product page copy uniqueness, breadcrumb structured data, and blocking faceted navigation from crawlers.

## Product Page Optimization

```tsx
export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const product = await getProduct(params.slug)
  if (!product) return {}

  return {
    title: `${product.name} | ${STORE_NAME}`,
    description: product.seoDescription || product.description.slice(0, 160),
    openGraph: {
      title: product.name,
      description: product.description.slice(0, 200),
      images: [{ url: product.images[0].url, width: 1200, height: 630 }],
    },
    alternates: {
      canonical: `${BASE_URL}/products/${product.slug}`,
    },
  }
}
```

## Product Schema Markup

```ts
// Build the JSON-LD object server-side from controlled data
// Pass as a string prop to a script-injecting component
function buildProductSchema(product: Product): string {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    description: product.description,
    image: product.images.map(img => img.url),
    sku: product.sku,
    brand: { '@type': 'Brand', name: product.brand },
    offers: {
      '@type': 'Offer',
      price: (product.priceCents / 100).toFixed(2),
      priceCurrency: 'USD',
      availability: product.inStock
        ? 'https://schema.org/InStock'
        : 'https://schema.org/OutOfStock',
      seller: { '@type': 'Organization', name: STORE_NAME },
    },
    ...(product.reviewCount > 0 && {
      aggregateRating: {
        '@type': 'AggregateRating',
        ratingValue: product.averageRating.toFixed(1),
        reviewCount: product.reviewCount,
      },
    }),
  }
  // JSON.stringify on a server-controlled object — safe, no user-controlled fields
  return JSON.stringify(schema)
}
```

The `offers.availability` and `aggregateRating` fields enable Rich Result eligibility in Google Search.

## Category Page Strategy

Category pages should be optimized for broader keywords, not product names:

```tsx
export default function CategoryPage({ category }: { category: Category }) {
  return (
    <>
      <h1>{category.seoH1 || category.name}</h1>
      {category.description && (
        <div className="prose mb-8">
          <p>{category.description}</p>
        </div>
      )}
      <ProductGrid products={category.products} />
      {/* Below-fold editorial content for SEO */}
      {category.seoContent && (
        <div className="prose mt-12 text-sm text-gray-600">
          {category.seoContent}
        </div>
      )}
    </>
  )
}
```

## Faceted Navigation (Critical)

Faceted URLs like `/shoes?color=red&size=10&brand=nike` create millions of unique URLs that crawlers index as thin duplicate content.

```
# robots.txt — block faceted URLs
User-agent: *
Disallow: /products?*
Allow: /products$
Allow: /shoes
Allow: /shoes/running
```

```tsx
// Alternative: canonical to clean URL
function FacetedSearchPage({ filters, products }: FacetedSearchProps) {
  return (
    <>
      {/* All faceted variants point canonical to clean category URL */}
      <link rel="canonical" href={`${BASE_URL}/shoes`} />
      <ProductGrid products={products} />
    </>
  )
}
```

Let faceted navigation work for users, but point canonical to the clean category URL and block faceted URLs in robots.txt.

## Duplicate Content from Product Variants

```tsx
function ProductVariantPage({ product, variant }: VariantPageProps) {
  // All color/size variants point canonical to the base product URL
  const canonicalUrl = `${BASE_URL}/products/${product.slug}`

  return (
    <>
      <link rel="canonical" href={canonicalUrl} />
      {/* ... */}
    </>
  )
}
```

Unless each variant has significantly different content (different description, unique images), use canonical to base product.

## Breadcrumb Schema

```ts
function buildBreadcrumbSchema(breadcrumbs: { name: string; url: string }[]): string {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: breadcrumbs.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: item.url,
    })),
  }
  return JSON.stringify(schema)
}
```

## Key Rules

- Block faceted search URLs in robots.txt — the single highest-impact e-commerce SEO action, preventing crawl budget waste on thin duplicate content.
- Product schema with `aggregateRating` enables star ratings in search results — significant CTR uplift, worth implementing before other schema types.
- Every product page needs unique `<h1>` and meta description — avoid the same template text across all variants.
- Category pages need editorial content below the product grid — Google needs substantive text to rank beyond a product list.
- `availability: InStock/OutOfStock` in schema must be accurate — mismatches cause Google Shopping penalties.
