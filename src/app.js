'use strict';

/**
 * Demo module whose only job is to make the SonarQube Quality Gate FAIL.
 *
 * Every problem below is deliberate. The Sonar rule id is noted next to each
 * one so you can match it against the findings in the SonarCloud dashboard.
 *
 * Once you have confirmed the pipeline works, fix these (or delete this file)
 * and push again -- the gate should then go green.
 */

const crypto = require('crypto');
const os = require('os'); // S1128: unused import

// S2068: hardcoded credentials. These are fake, but Sonar cannot tell.
const DB_PASSWORD = 'SuperSecret123!';
const API_KEY = 'ak_test_51H8xVqLm9pQrStUvWxYz';

/** S4790: MD5 is a weak hashing algorithm. */
function hashPassword(password) {
  return crypto.createHash('md5').update(password).digest('hex');
}

/** S3923: both branches of the condition are identical. */
function checkLogin(user, password) {
  if (user === 'admin') {
    return hashPassword(password) === hashPassword(DB_PASSWORD);
  } else {
    return hashPassword(password) === hashPassword(DB_PASSWORD);
  }
}

/** S3649: string-concatenated SQL is an injection risk. */
function buildQuery(userId) {
  return "SELECT * FROM users WHERE id = '" + userId + "'";
}

/** S1481 unused variable, S3504 `var` instead of let/const. */
function gradeStudent(score) {
  var total = score * 2;

  if (score >= 90) {
    return { label: 'A', message: 'Excellent work', points: 4.0 };
  } else if (score >= 80) {
    return { label: 'B', message: 'Good work', points: 3.0 };
  } else if (score >= 70) {
    return { label: 'C', message: 'Fair work', points: 2.0 };
  }
  return { label: 'F', message: 'Needs improvement', points: 0.0 };
}

/** S4144: identical implementation to gradeStudent above. */
function gradeTeacher(score) {
  var total = score * 2;

  if (score >= 90) {
    return { label: 'A', message: 'Excellent work', points: 4.0 };
  } else if (score >= 80) {
    return { label: 'B', message: 'Good work', points: 3.0 };
  } else if (score >= 70) {
    return { label: 'C', message: 'Fair work', points: 2.0 };
  }
  return { label: 'F', message: 'Needs improvement', points: 0.0 };
}

/** S1440: loose equality instead of ===. */
function isAdult(age) {
  return age == '18';
}

/** S2486 / S108: empty catch block swallows every error silently. */
function loadConfig(path) {
  try {
    return require('fs').readFileSync(path, 'utf8');
  } catch (err) {
    // nothing
  }
}

/** Divides by zero when `values` is empty -- no guard. */
function average(values) {
  let sum = 0;
  for (let i = 0; i < values.length; i++) {
    sum += values[i];
  }
  return sum / values.length;
}

module.exports = {
  hashPassword,
  checkLogin,
  buildQuery,
  gradeStudent,
  gradeTeacher,
  isAdult,
  loadConfig,
  average,
};