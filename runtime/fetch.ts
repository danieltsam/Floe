//
//  fetch.ts
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

// Node's fetch rejects with a TypeError whose cause carries the socket's code; Bun puts the code on the error itself,
// with no cause or with a cause that is only a word, depending on its version.
// Extensions are written against Node, and read the code there to say that the server they need is not running.
export function withNodeCause(fetch: typeof globalThis.fetch): typeof globalThis.fetch {
  const wrapped = (...args: Parameters<typeof globalThis.fetch>) =>
    fetch(...args).catch((error: unknown) => {
      const code = (error as { code?: unknown } | null)?.code;
      const cause = error instanceof TypeError ? error.cause : undefined;
      const causeHasCode = typeof cause === "object" && cause !== null && "code" in cause;
      if (error instanceof TypeError && typeof code === "string" && !causeHasCode) {
        error.cause = Object.assign(new Error(typeof cause === "string" ? cause : error.message), { code });
      }
      throw error;
    });
  // preconnect, and whatever else Bun hangs on fetch.
  return Object.assign(wrapped, fetch);
}
