'use strict';
module.exports = function(app) {
  var shyftTrustAnchorManager = require('../controllers/trustAnchorManagerController');

  //Shyft Trust Anchor Manager
  app.route('/setup_primary_administrator')
    .post(shyftTrustAnchorManager.set_primary_administrator);
  
    app.route('/setup_administrator')
    .post(shyftTrustAnchorManager.set_administrator);

    app.route('/onboard_trust_anchor')
    .post(shyftTrustAnchorManager.onboard_trust_anchor);

  
};