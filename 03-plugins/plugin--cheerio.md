# Plugin: Cheerio

## Overview

Cheerio is a jQuery-like library for parsing and traversing HTML in Node.js. Use it for: web scraping, parsing API responses that return HTML, extracting data from email templates, server-side HTML manipulation.

## Install

```bash
npm install cheerio
```

## Basic Parsing

```ts
import * as cheerio from 'cheerio'

const html = `
<div class="product">
  <h2 class="title">Wireless Headphones</h2>
  <span class="price">$89.99</span>
  <div class="reviews">
    <span class="count">142 reviews</span>
    <span class="rating">4.7</span>
  </div>
</div>
`

const $ = cheerio.load(html)

const title = $('.product .title').text()         // 'Wireless Headphones'
const price = $('.product .price').text()         // '$89.99'
const rating = $('.product .rating').text()       // '4.7'
const reviewCount = parseInt($('.count').text())  // 142
```

## Common Selectors

```ts
// CSS selectors (same as jQuery/document.querySelector)
$('.class-name')          // By class
$('#element-id')          // By ID
$('a[href]')              // Attribute exists
$('a[href^="https"]')     // Attribute starts with
$('a[href$=".pdf"]')      // Attribute ends with
$('li:first-child')       // Pseudo-selectors
$('tr:nth-child(odd)')    // Nth child
$('p > a')                // Direct child
$('div a')                // Descendant
```

## Extracting Attributes

```ts
// Get href from links
$('a').each((index, el) => {
  const href = $(el).attr('href')
  const text = $(el).text()
  console.log({ href, text })
})

// Get all image srcs
const images: string[] = []
$('img').each((_, el) => {
  const src = $(el).attr('src')
  if (src) images.push(src)
})

// Get data attribute
const productId = $('.product').attr('data-id')
```

## Structured Data Extraction

```ts
interface Product {
  name: string
  price: number
  url: string
  imageUrl: string
}

function extractProducts(html: string): Product[] {
  const $ = cheerio.load(html)
  const products: Product[] = []

  $('.product-card').each((_, el) => {
    const name = $(el).find('.product-name').text().trim()
    const priceText = $(el).find('.price').text().replace(/[^0-9.]/g, '')
    const price = parseFloat(priceText)
    const url = $(el).find('a').attr('href') ?? ''
    const imageUrl = $(el).find('img').attr('src') ?? ''

    if (name && !isNaN(price)) {
      products.push({ name, price, url, imageUrl })
    }
  })

  return products
}
```

## Scraping with Fetch

```ts
import * as cheerio from 'cheerio'

async function scrapeProducts(url: string): Promise<Product[]> {
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; research bot)',
    },
  })
  
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  
  const html = await response.text()
  return extractProducts(html)
}
```

Always set a descriptive User-Agent. Blank or bot-looking agents get blocked.

## HTML Manipulation

```ts
// Modify HTML before rendering
const $ = cheerio.load(emailHtml)

// Add tracking parameters to all links
$('a[href]').each((_, el) => {
  const href = $(el).attr('href') ?? ''
  if (href.startsWith('http')) {
    $(el).attr('href', `${href}?utm_source=email&utm_campaign=welcome`)
  }
})

// Remove elements
$('.unsubscribe-text').remove()

// Add class
$('img').addClass('responsive-image')

// Get modified HTML
const modifiedHtml = $.html()
```

## Table Parsing

HTML tables are common in data exports:

```ts
function parseTable(tableHtml: string): Record<string, string>[] {
  const $ = cheerio.load(tableHtml)
  const headers: string[] = []
  const rows: Record<string, string>[] = []

  $('thead th').each((_, el) => {
    headers.push($(el).text().trim())
  })

  $('tbody tr').each((_, row) => {
    const rowData: Record<string, string> = {}
    $(row).find('td').each((colIndex, cell) => {
      rowData[headers[colIndex] ?? colIndex.toString()] = $(cell).text().trim()
    })
    rows.push(rowData)
  })

  return rows
}
```

## Rate Limiting for Scraping

Never scrape without delays:

```ts
async function scrapeMultiplePages(urls: string[]) {
  const results = []
  for (const url of urls) {
    results.push(await scrapeProducts(url))
    // Respectful delay between requests
    await new Promise(resolve => setTimeout(resolve, 1000 + Math.random() * 1000))
  }
  return results
}
```

Check the site's `robots.txt` before scraping. Respect `Crawl-delay` directives.

## Cheerio vs Playwright

| | Cheerio | Playwright |
|--|---------|---------|
| JavaScript rendering | No | Yes |
| Speed | Fast | Slow (headless browser) |
| JavaScript-heavy sites | Can't scrape | Can scrape |
| Resource usage | Low | High |
| Use when | Static HTML | Dynamic/SPA content |
