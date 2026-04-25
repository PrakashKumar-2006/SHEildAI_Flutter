const SOS = require('../models/SOS');

// @desc    Create new SOS alert
// @route   POST /api/sos
exports.createSOS = async (req, res) => {
  const { location } = req.body;

  try {
    const sos = await SOS.create({
      user_phone: req.user.phone,
      location,
      status: 'active'
    });

    res.status(201).json(sos);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Get user's SOS history
// @route   GET /api/sos/history
exports.getSOSHistory = async (req, res) => {
  try {
    const sosList = await SOS.find({ user_phone: req.user.phone }).sort({ createdAt: -1 });
    res.json(sosList);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Update SOS status
// @route   PUT /api/sos/:id/status
exports.updateSOSStatus = async (req, res) => {
  const { status } = req.body;

  try {
    const sos = await SOS.findById(req.params.id);

    if (!sos) {
      return res.status(404).json({ message: 'SOS alert not found' });
    }

    if (sos.user_phone !== req.user.phone) {
      return res.status(401).json({ message: 'Not authorized to update this SOS' });
    }

    sos.status = status;
    await sos.save();

    res.json(sos);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
