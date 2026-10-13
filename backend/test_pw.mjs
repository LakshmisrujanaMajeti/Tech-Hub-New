import bcrypt from 'bcryptjs';

const hash = '$2a$10$/ccCvp6cCKOvXzHVaeKdHuBPYYOLpXPp1tycQ9Xt9GFQ0CuKMMXnK';

console.log('Testing "Student@123":', bcrypt.compareSync('Student@123', hash));
console.log('Testing "student@123":', bcrypt.compareSync('student@123', hash));
console.log('Testing "Cognito@123":', bcrypt.compareSync('Cognito@123', hash));
console.log('Testing "Cognito@2025":', bcrypt.compareSync('Cognito@2025', hash));

const inputWithSpace = '  harish. ece@adarsh.ac.in  ';
const cleaned = inputWithSpace.replace(/\s+/g, '').toLowerCase();
console.log('Cleaned input with space:', cleaned);
