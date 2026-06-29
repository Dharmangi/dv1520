const express = require('express');
const router = express.Router();
const controller = require('../controllers/dashboardController');

router.get('/summary', controller.summary);
router.get('/range-summary', controller.rangeSummary);
router.get('/by-person', controller.byPerson);
router.get('/by-category', controller.byCategory);
router.get('/time-series', controller.timeSeries);

module.exports = router;
