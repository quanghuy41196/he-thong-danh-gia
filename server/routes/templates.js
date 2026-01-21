import express from 'express';
import {
  getAllTemplates,
  getTemplateById,
  getTemplateBySlug,
  createTemplate,
  updateTemplate,
  deleteTemplate,
} from '../controllers/templateController.js';

const router = express.Router();

router.get('/', getAllTemplates);
router.get('/slug/:slug', getTemplateBySlug);
router.get('/:id', getTemplateById);
router.post('/', createTemplate);
router.put('/:id', updateTemplate);
router.delete('/:id', deleteTemplate);

export default router;
