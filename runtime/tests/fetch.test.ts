//
//  fetch.test.ts
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import { describe, expect, test } from "bun:test";
import { withNodeCause } from "../fetch";

describe("withNodeCause", () => {
  // What an extension tests for before it says that its server is not running.
  test("a refused connection rejects with the code on the error's cause, as Node's fetch does", async () => {
    const server = Bun.serve({ port: 0, fetch: () => new Response("") });
    const url = `http://127.0.0.1:${server.port}/api/tags`;
    await server.stop(true);

    const bare = await fetch(url).catch((error) => error);
    expect([bare instanceof TypeError, bare.code, bare.cause]).toEqual([true, "ECONNREFUSED", undefined]);

    const error = await withNodeCause(fetch)(url).catch((error) => error);
    expect(error instanceof TypeError && error.cause && error.cause.code === "ECONNREFUSED").toBe(true);
    expect(error.code).toBe("ECONNREFUSED");
  });

  test("an answer, an error without a code and one that has its cause pass through as they are", async () => {
    const response = new Response("ok");
    expect(await withNodeCause((async () => response) as never)("http://example.invalid")).toBe(response);

    const plain = new TypeError("not a URL");
    const caused = Object.assign(new TypeError("fetch failed", { cause: "the reason" }), { code: "ENOTFOUND" });
    for (const thrown of [plain, caused, "a string"]) {
      const rejects = (async () => {
        throw thrown;
      }) as never;
      expect(await withNodeCause(rejects)("http://example.invalid").catch((error) => error)).toBe(thrown);
    }
    expect([plain.cause, caused.cause]).toEqual([undefined, "the reason"]);
  });

  test("what fetch carries stays on it", () => {
    expect(withNodeCause(fetch).preconnect).toBe(fetch.preconnect);
  });
});
