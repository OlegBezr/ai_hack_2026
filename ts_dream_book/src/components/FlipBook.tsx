import {
  forwardRef,
  useEffect,
  useImperativeHandle,
  useRef,
  type ReactNode,
} from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { PageFlip } from '../vendor/stpageflip/PageFlip';

export interface FlipPage {
  /** Presentational React content for the page (serialized to static HTML). */
  content: ReactNode;
  /** Render as a rigid "hard" page (covers). */
  hard?: boolean;
}

export interface FlipBookHandle {
  next: () => void;
  prev: () => void;
  turnTo: (page: number) => void;
  currentPage: () => number;
  pageCount: () => number;
}

interface FlipBookProps {
  pages: FlipPage[];
  width?: number;
  height?: number;
  /**
   * When false, the book always shows a two-page spread (landscape). When true,
   * it may collapse to a single page in portrait. The reader sets this from its
   * own breakpoint so single/spread mode is deterministic, not aspect-driven.
   */
  usePortrait?: boolean;
  /** Fired after a flip settles, with the new current page (leaf) index. */
  onFlip?: (pageIndex: number) => void;
  className?: string;
}

/**
 * Thin React wrapper around the (vendored, touch-patched) StPageFlip engine.
 *
 * The page content is presentational, so we serialize it to static HTML and let
 * StPageFlip fully own those DOM nodes — this avoids the React-vs-library
 * DOM-ownership war that breaks naive ref-based integrations. The book re-inits
 * whenever `pages` changes identity (keep it stable with useMemo upstream).
 */
export const FlipBook = forwardRef<FlipBookHandle, FlipBookProps>(function FlipBook(
  { pages, width = 550, height = 733, usePortrait = true, onFlip, className },
  ref,
) {
  const hostRef = useRef<HTMLDivElement>(null);
  const flipRef = useRef<PageFlip | null>(null);

  useImperativeHandle(
    ref,
    () => ({
      next: () => flipRef.current?.flipNext(),
      prev: () => flipRef.current?.flipPrev(),
      turnTo: (page: number) => flipRef.current?.turnToPage(page),
      currentPage: () => flipRef.current?.getCurrentPageIndex() ?? 0,
      pageCount: () => flipRef.current?.getPageCount() ?? 0,
    }),
    [],
  );

  useEffect(() => {
    const host = hostRef.current;
    if (!host) return;

    // Give StPageFlip its OWN container that React does not track. React only
    // owns the empty `host`; all of the library's DOM mutation (and our
    // innerHTML) happens inside `book`, so React's reconciliation / StrictMode
    // double-mount never fights the library over the same node.
    const book = document.createElement('div');
    book.innerHTML = pages
      .map(
        (p) =>
          `<div class="df-page${p.hard ? ' df-page--hard' : ''}" data-density="${
            p.hard ? 'hard' : 'soft'
          }">${renderToStaticMarkup(p.content)}</div>`,
      )
      .join('');
    host.appendChild(book);

    const pageFlip = new PageFlip(book, {
      width,
      height,
      size: 'stretch',
      minWidth: 300,
      maxWidth: 720,
      minHeight: 400,
      maxHeight: 960,
      drawShadow: true,
      flippingTime: 700,
      maxShadowOpacity: 0.5,
      showCover: true,
      mobileScrollSupport: false,
      // The reader drives orientation explicitly from its 600px breakpoint so
      // single vs. spread is deterministic (forced spread when usePortrait is
      // false), instead of being inferred from the container aspect ratio.
      usePortrait,
      // patched library behavior we rely on:
      showPageCorners: false, // no hover-fold; flip starts on press/drag only
      // cast at the vendored-lib boundary: `size` is a string-valued const enum
      // in StPageFlip; the literal is the correct runtime value.
    } as ConstructorParameters<typeof PageFlip>[1]);

    pageFlip.loadFromHTML(book.querySelectorAll<HTMLElement>('.df-page'));
    if (onFlip) pageFlip.on('flip', (e) => onFlip(e.data as number));

    flipRef.current = pageFlip;

    return () => {
      pageFlip.destroy();
      book.remove();
      flipRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pages, width, height, usePortrait]);

  return <div ref={hostRef} className={className} />;
});
