const express = require("express");
const {
  listQuestions,
  addQuestion,
  removeQuestion,
} = require("../store/quizStore");

function buildQuizRouter(bus) {
  const router = express.Router();

  // List all questions
  router.get("/questions", (req, res) => {
    res.json(listQuestions());
  });

  // Add question (dosen)
  router.post("/questions", (req, res) => {
    const { text, options, answerIndex } = req.body;
    if (!text || !Array.isArray(options) || options.length !== 4) {
      return res.status(400).json({ message: "text and 4 options required" });
    }
    try {
      const q = addQuestion({ text, options, answerIndex });
      bus.emit("question:added", q);
      res.status(201).json(q);
    } catch (e) {
      res.status(400).json({ message: e.message });
    }
  });

  // Remove question (dosen)
  router.delete("/questions/:id", (req, res) => {
    const ok = removeQuestion(req.params.id);
    if (!ok) return res.status(404).json({ message: "not found" });
    bus.emit("question:removed", { id: req.params.id });
    res.json({ ok: true });
  });

  return router;
}

module.exports = { buildQuizRouter };
