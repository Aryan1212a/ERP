-- Fix invalid emails in PostgreSQL database
-- This script updates all emails that have a period immediately before the @

BEGIN;

-- Show users with invalid emails
SELECT id, full_name, email FROM users 
WHERE email LIKE '%.@%'
ORDER BY id;

-- Update invalid emails for teachers (they have titles like Dr., Prof., etc.)
UPDATE users 
SET email = LOWER(CONCAT(
  SUBSTRING_INDEX(REPLACE(REPLACE(REPLACE(REPLACE(full_name, 'Dr. ', ''), 'Prof. ', ''), 'Mr. ', ''), 'Ms. ', ''), ' ', 1),
  SUBSTRING_INDEX(REPLACE(REPLACE(REPLACE(REPLACE(full_name, 'Dr. ', ''), 'Prof. ', ''), 'Mr. ', ''), 'Ms. ', ''), ' ', -1),
  id,
  '@school.edu'
))
WHERE email LIKE '%.@%';

-- Show fixed emails
SELECT id, full_name, email FROM users 
WHERE CONCAT(id) IN (
  SELECT id FROM users 
  WHERE email LIKE '%.@%'
)
ORDER BY id;

COMMIT;
