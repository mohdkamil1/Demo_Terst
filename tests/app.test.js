'use strict';

// Uses Node's built-in test runner -- no npm install needed.
// Run with:  npm test

const test = require('node:test');
const assert = require('node:assert');

const { gradeStudent, average, isAdult } = require('../src/app');

test('gradeStudent returns the top band', () => {
  const result = gradeStudent(95);
  assert.strictEqual(result.label, 'A');
  assert.strictEqual(result.points, 4.0);
});

test('gradeStudent returns the fail band', () => {
  const result = gradeStudent(10);
  assert.strictEqual(result.label, 'F');
  assert.strictEqual(result.points, 0.0);
});

test('average computes the mean', () => {
  assert.strictEqual(average([2, 4, 6]), 4);
});

test('isAdult accepts the string form', () => {
  assert.strictEqual(isAdult(18), true);
});