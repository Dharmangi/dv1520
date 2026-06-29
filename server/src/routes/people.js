const express = require('express');
const router = express.Router();
const controller = require('../controllers/peopleController');

router.get('/', controller.list);
router.get('/:id/ledger', controller.ledger);
router.post('/', controller.create);
router.put('/:id', controller.update);
router.delete('/:id', controller.remove);

module.exports = router;
