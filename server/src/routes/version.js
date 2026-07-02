const express = require('express');
const router = express.Router();
const controller = require('../controllers/versionController');

router.get('/', controller.getVersion);

module.exports = router;
