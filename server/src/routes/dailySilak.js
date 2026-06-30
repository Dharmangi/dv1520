const express = require('express');
const router = express.Router();
const controller = require('../controllers/dailySilakController');

router.get('/people', controller.getPeople);
router.get('/', controller.list);
router.get('/by-date', controller.getByDate);
router.post('/entry', controller.addEntry);
router.put('/:id/entry/:entryId', controller.editEntry);
router.delete('/:id/entry/:entryId', controller.removeEntry);
router.post('/:date/sync', controller.sync);

module.exports = router;
