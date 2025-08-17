// In-memory quiz store. Replace with DB in production.
const { v4: uuidv4 } = require('uuid');

const questions = new Map(); // id -> { id, text, options: [{id, text}], answerId }

function listQuestions() {
  return Array.from(questions.values());
}

function addQuestion({ text, options, answerIndex }) {
  const id = uuidv4();
  const optionObjs = options.map((t) => ({ id: uuidv4(), text: t }));
  const answerId = optionObjs[answerIndex]?.id;
  if (!answerId) throw new Error('Invalid answer index');
  const q = { id, text, options: optionObjs, answerId };
  questions.set(id, q);
  return q;
}

function removeQuestion(id) {
  return questions.delete(id);
}

function getQuestion(id) {
  return questions.get(id) || null;
}

module.exports = { listQuestions, addQuestion, removeQuestion, getQuestion };
