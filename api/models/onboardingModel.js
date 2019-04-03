'use strict'
var mongoose = require('mongoose');
var Schema = mongoose.Schema;

var OnboardingSchema = new Schema({
  walletaddress: String
  
});

module.exports = mongoose.model('Onboarding', OnboardingSchema);