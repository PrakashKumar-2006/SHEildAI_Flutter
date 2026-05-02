const express = require('express');
const router = express.Router();
const { triggerSOS, updateStatus } = require('../controllers/sosController');
// Note: Middleware protection is optional for public SOS triggers but recommended
// const { protect } = require('../middleware/auth');

router.post('/trigger', triggerSOS);
router.put('/:sosId/status', updateStatus);

module.exports = router;
