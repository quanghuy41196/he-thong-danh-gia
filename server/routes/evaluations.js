import express from 'express';
import {
  getAllEvaluations,
  getEvaluationsBySession,
  getEvaluationsByTemplate,
  submitEvaluation,
  getSessionStatistics,
  getTemplateStatistics,
  deleteEvaluation,
  deleteAllEvaluationsByTemplate,
} from '../controllers/evaluationController.js';

const router = express.Router();

router.get('/', getAllEvaluations);
router.get('/template/:templateId', getEvaluationsByTemplate);
router.get('/template/:templateId/statistics', getTemplateStatistics);
router.get('/session/:sessionId', getEvaluationsBySession);
router.get('/session/:sessionId/statistics', getSessionStatistics);
router.post('/', submitEvaluation);
router.delete('/template/:templateId', deleteAllEvaluationsByTemplate);
router.delete('/:id', deleteEvaluation);

export default router;
