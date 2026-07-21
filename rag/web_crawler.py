"""
Web crawler for importing website content into the RAG system.
Supports sitemap.xml parsing, recursive crawling, depth control, and duplicate avoidance.
"""
import re
import time
import logging
import hashlib
from urllib.parse import urljoin, urlparse
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def crawl_website(
    start_url: str,
    max_depth: int = None,
    max_pages: int = None,
    delay: float = None,
) -> list[dict]:
    """
    Crawl a website starting from start_url.

    Returns list of dicts: {url, title, text, depth}
    """
    import httpx
    from bs4 import BeautifulSoup

    max_depth = max_depth or settings.CRAWL_MAX_DEPTH
    max_pages = max_pages or settings.CRAWL_MAX_PAGES
    delay = delay or settings.CRAWL_DELAY

    visited = set()
    results = []
    queue = [(start_url, 0)]  # (url, depth)

    # Parse domain for same-origin restriction
    parsed_start = urlparse(start_url)
    base_domain = parsed_start.netloc

    logger.info(f"Starting crawl: {start_url}, max_depth={max_depth}, max_pages={max_pages}")

    with httpx.Client(
        timeout=settings.CRAWL_TIMEOUT,
        follow_redirects=True,
        headers={"User-Agent": "RagChat Web Crawler/2.0"},
    ) as client:
        while queue and len(results) < max_pages:
            url, depth = queue.pop(0)

            # Deduplicate
            url_hash = hashlib.md5(url.encode()).hexdigest()
            if url_hash in visited:
                continue
            visited.add(url_hash)

            # Stay within same domain
            parsed = urlparse(url)
            if parsed.netloc != base_domain:
                continue

            # Skip non-HTML resources
            path = parsed.path.lower()
            skip_extensions = (
                ".jpg", ".jpeg", ".png", ".gif", ".svg", ".ico",
                ".pdf", ".doc", ".docx", ".xls", ".xlsx",
                ".mp3", ".mp4", ".zip", ".tar", ".gz",
                ".css", ".js", ".xml", ".rss",
            )
            if any(path.endswith(ext) for ext in skip_extensions):
                continue

            try:
                response = client.get(url)
                if response.status_code != 200:
                    logger.debug(f"Skipping {url}: HTTP {response.status_code}")
                    continue

                content_type = response.headers.get("content-type", "")
                if "text/html" not in content_type:
                    continue

                soup = BeautifulSoup(response.text, "html.parser")

                # Extract title
                title = ""
                title_tag = soup.find("title")
                if title_tag:
                    title = title_tag.get_text(strip=True)

                # Clean the content
                text = _clean_html(soup)

                if text.strip():
                    results.append({
                        "url": url,
                        "title": title,
                        "text": text,
                        "depth": depth,
                    })
                    logger.debug(f"Crawled: {url} ({len(text)} chars)")

                # Find links for deeper crawling
                if depth < max_depth:
                    for link in soup.find_all("a", href=True):
                        href = link["href"]
                        next_url = urljoin(url, href)
                        next_hash = hashlib.md5(next_url.encode()).hexdigest()
                        if next_hash not in visited:
                            queue.append((next_url, depth + 1))

                # Rate limiting
                if delay > 0:
                    time.sleep(delay)

            except Exception as e:
                logger.warning(f"Failed to crawl {url}: {e}")
                continue

    logger.info(f"Crawl complete: {len(results)} pages from {start_url}")
    return results


def parse_sitemap(sitemap_url: str) -> list[str]:
    """Parse a sitemap.xml file and return list of URLs."""
    import httpx

    try:
        response = httpx.get(sitemap_url, timeout=settings.CRAWL_TIMEOUT, follow_redirects=True)
        if response.status_code != 200:
            logger.warning(f"Failed to fetch sitemap: HTTP {response.status_code}")
            return []

        # Parse XML
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(response.text, "xml")

        urls = []
        for loc in soup.find_all("loc"):
            url = loc.get_text(strip=True)
            if url:
                urls.append(url)

        # Check for nested sitemaps
        for sitemap in soup.find_all("sitemap"):
            nested_loc = sitemap.find("loc")
            if nested_loc:
                nested_url = nested_loc.get_text(strip=True)
                if nested_url:
                    urls.extend(parse_sitemap(nested_url))

        logger.info(f"Parsed sitemap: {len(urls)} URLs from {sitemap_url}")
        return urls
    except Exception as e:
        logger.error(f"Sitemap parsing failed: {e}")
        return []


def crawl_from_sitemap(
    sitemap_url: str,
    max_pages: int = None,
    delay: float = None,
) -> list[dict]:
    """Crawl a website starting from its sitemap.xml."""
    max_pages = max_pages or settings.CRAWL_MAX_PAGES
    delay = delay or settings.CRAWL_DELAY

    urls = parse_sitemap(sitemap_url)
    if not urls:
        return []

    # Limit to max_pages
    urls = urls[:max_pages]

    results = []
    import httpx
    from bs4 import BeautifulSoup

    logger.info(f"Crawling {len(urls)} URLs from sitemap")

    with httpx.Client(
        timeout=settings.CRAWL_TIMEOUT,
        follow_redirects=True,
        headers={"User-Agent": "RagChat Web Crawler/2.0"},
    ) as client:
        for url in urls:
            try:
                response = client.get(url)
                if response.status_code != 200:
                    continue

                soup = BeautifulSoup(response.text, "html.parser")
                title = ""
                title_tag = soup.find("title")
                if title_tag:
                    title = title_tag.get_text(strip=True)

                text = _clean_html(soup)
                if text.strip():
                    results.append({
                        "url": url,
                        "title": title,
                        "text": text,
                        "depth": 0,
                    })

                if delay > 0:
                    time.sleep(delay)
            except Exception as e:
                logger.warning(f"Failed to fetch {url}: {e}")

    logger.info(f"Sitemap crawl complete: {len(results)} pages")
    return results


def _clean_html(soup) -> str:
    """Extract clean text from HTML, removing scripts, styles, and navigation."""
    # Remove unwanted elements
    for tag in soup.find_all(["script", "style", "nav", "footer", "header", "aside"]):
        tag.decompose()

    # Get text
    text = soup.get_text(separator="\n", strip=True)

    # Clean up whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]+', ' ', text)

    return text.strip()


def pages_to_chunks(pages: list[dict], source_prefix: str = "") -> list[dict]:
    """Convert crawled pages to document chunks ready for ingestion."""
    chunks = []
    for page in pages:
        filename = f"{source_prefix}{urlparse(page['url']).path}" or page.get("title", "page")
        chunks.append({
            "text": page["text"],
            "source": filename,
            "url": page["url"],
            "title": page.get("title", ""),
            "language": "en",
        })
    return chunks
