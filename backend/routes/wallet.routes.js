const express = require('express');
const router = express.Router();
const pool = require('../db');
const asyncHandler = require('../middleware/asyncHandler');
const { requireSelfOrAdmin } = require('../auth');
const { PKPass } = require('passkit-generator');

// 10. Apple Wallet 패스 발급 API
router.get('/apple-pass/:person_id', requireSelfOrAdmin('person_id'), asyncHandler(async (req, res) => {
  const { person_id } = req.params;
  const result = await pool.query('SELECT * FROM members WHERE person_id = $1', [person_id]);
  if (result.rows.length === 0) return res.status(404).send("성도를 찾을 수 없습니다.");

  const member = result.rows[0];
  const fullName = `${member.last_name}${member.first_name}`;
  const qrData = `${fullName}|${member.pin_code}`;

  // Pass 생성 (실제 구현 시 인증서 파일들이 필요합니다)
  const pass = await PKPass.from({
    model: "./models/church_pass.pass", // 패스 디자인 템플릿 경로
    certificates: {
      wwdr: process.env.APPLE_WWDR_CERT,
      signerCert: process.env.APPLE_SIGNER_CERT,
      signerKey: process.env.APPLE_SIGNER_KEY,
      signerKeyPassword: process.env.APPLE_CERT_PASSWORD,
    },
  });

  pass.setBarcodes({
    format: "PKBarcodeFormatQR",
    message: qrData,
    messageEncoding: "iso-8859-1",
  });

  pass.primaryFields.add({ key: "member", label: "성도명", value: fullName });
  pass.secondaryFields.add({ key: "title", label: "직분", value: member.church_title || "성도" });

  const buffer = pass.export();
  res.setHeader("Content-Type", "application/vnd.apple.pkpass");
  res.setHeader("Content-Disposition", "attachment; filename=church_pass.pkpass");
  res.send(buffer);
}));

module.exports = router;
