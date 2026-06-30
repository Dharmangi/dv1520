const express = require('express');
const router = express.Router();
const controller = require('../controllers/outstandingController');

router.get('/', controller.list);
router.get('/history', controller.history);
router.post('/', controller.create);
router.post('/:id/settle', controller.settle);
router.delete('/:id', controller.remove);

module.exports = router;
