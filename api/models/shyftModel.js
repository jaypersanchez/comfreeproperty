'use strict';
var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var ShyftSchema = new Schema({
  walletaddress: {
    type: String
  },
  Created_date: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Shyft', ShyftSchema);