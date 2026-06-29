const express = require('express');
const router = express.Router();
const controller = require('../controllers/havalaController');

router.get('/', controller.list);
router.post('/', controller.create);
router.patch('/:id/settle', controller.settle);
router.delete('/:id', controller.remove);

module.exports = router;
