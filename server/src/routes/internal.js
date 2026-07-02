const express = require('express');
const router = express.Router();
const requireInternalToken = require('../middleware/internalAuth');
const controller = require('../controllers/internalUpdateController');

router.post('/update-version', requireInternalToken, controller.postUpdateVersion);

module.exports = router;
