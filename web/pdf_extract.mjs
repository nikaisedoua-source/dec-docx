import { getDocument, GlobalWorkerOptions } from './vendor/pdfjs/pdf.mjs';

GlobalWorkerOptions.workerSrc = new URL('./vendor/pdfjs/pdf.worker.mjs', import.meta.url).href;

// Keep the text local: PDF bytes are parsed in the browser's worker.
export async function extractPdfText(bytes) {
  const task = getDocument({
    data: bytes.slice(),
    isEvalSupported: false,
    cMapUrl: new URL('./vendor/pdfjs/cmaps/', import.meta.url).href,
    cMapPacked: true,
    standardFontDataUrl: new URL('./vendor/pdfjs/standard_fonts/', import.meta.url).href,
    wasmUrl: new URL('./vendor/pdfjs/wasm/', import.meta.url).href,
  });
  try {
    const pdf = await task.promise;
    const pages = [];
    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const content = await page.getTextContent();
      let text = '';
      for (const item of content.items) {
        if (!('str' in item)) continue;
        text += item.str;
        if (item.hasEOL) text += '\n';
      }
      pages.push(text);
      page.cleanup();
    }
    return pages.join('\n');
  } finally {
    await task.destroy();
  }
}
