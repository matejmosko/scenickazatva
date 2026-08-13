"use strict";

const test = require("node:test");
const assert = require("node:assert");
const {shouldNotify, buildArticlePayload} = require("../articles");

test("shouldNotify", async (t) => {
  await t.test("true when the newest post differs from the stored one", () => {
    assert.strictEqual(shouldNotify(10, 11), true);
    assert.strictEqual(shouldNotify(null, 11), true);
    assert.strictEqual(shouldNotify("10", 11), true);
  });

  await t.test("false when nothing new arrived", () => {
    assert.strictEqual(shouldNotify(11, 11), false);
    assert.strictEqual(shouldNotify("11", 11), false);
  });

  await t.test("false when the feed is empty", () => {
    assert.strictEqual(shouldNotify(10, undefined), false);
    assert.strictEqual(shouldNotify(10, null), false);
  });
});

test("buildArticlePayload", () => {
  const payload = buildArticlePayload({
    id: 42,
    title: {rendered: "Nov\u00fd \u010dl\u00e1nok &#8211; s &amp; linkou"},
  });

  assert.strictEqual(
      payload.notification.title,
      "Nov\u00fd \u010dl\u00e1nok na javisko.sk");
  assert.strictEqual(
      payload.notification.body,
      "Nov\u00fd \u010dl\u00e1nok \u2013 s & linkou");
  assert.strictEqual(payload.topic, "magazine_updates");
  assert.deepStrictEqual(payload.data, {id: "42", type: "magazine"});
});
