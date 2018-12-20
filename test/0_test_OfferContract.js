var OfferContract = artifacts.require("OfferContract");
var SaleConditionContract = artifacts.require("SaleConditionContract");

contract('OfferContract', function(accounts) {
    /*
    * Accounts from Ganache
    */
    var addressA = accounts[0];
    var addressB = accounts[1];
    var addressC = accounts[2];
    var addressD = accounts[3];

    let offerContract;
    var offerAmount = 500000;
    var accept = true;

    let saleConditionContract;
    //condition list
    var WallsPainted = true;
    var CarpetCleaned = true;
    var WindowsWashed = true;

    it("should have the shared context", async() => {
        offerContract = await OfferContract.deployed();
        
        console.log("\t\t[ OfferContract address :: " + offerContract.address + " ]");
        console.log("\t\t[ Coinbase account address:: " + addressA + " ]");
        console.log("\t\t[ Seller account address:: " + addressB + " ]");
        console.log("\t\t[ Buyer account address:: " + addressC + " ]");
        //console.log("\t\t[ accounts D address:: " + addressD + " ]");

        assert(offerContract !== undefined, 'has no OfferContract instance');

        //return true;
    }).timeout(100000);

    it("Set Seller Wallet Address :: " + addressB, async () => {
        await offerContract.setSellerAddress(addressB);
        let sellerAddy = await offerContract.getSellerAddress.call();
        assert.equal(sellerAddy, addressB, "Seller Address does not match with what was setup");
    }).timeout(100000);

    it("Set Buyer Wallet Address :: " + addressC, async () => {
        await offerContract.setBuyerAddress(addressC);
        let buyerAddy = await offerContract.getBuyerAddress.call();
        assert.equal(buyerAddy, addressC, "Buyer Address does not match with what was setup");
    }).timeout(100000);

    it("Set Buyer Offer", async() => {
        await offerContract.setBuyerOffer(offerAmount);
        let offeredAmount = await offerContract.getOfferAmount.call();
        assert.equal(offerAmount, offeredAmount,"Amount offered does not equal with offer on record");
    }).timeout(100000);

    it("Buyer offer accepted", async() => {
        let _accept = await offerContract.accept(accept);
        let isaccepted = await offerContract.isOfferAccepted.call();
        //assert.equal(_accept, isaccepted,"Offer does not match what is on record");
        assert.equal(_accept, true, 'Offer not accepted.  Will not initiate Sale Condition contract');
    }).timeout(100000);

    /* Need to test offer expiration date */

    /* Test Sales Conditions are met before executing
    * Escrow contract
    */
    /*it("Is Offer Contract Valid", async() => {
        saleConditionContract = await SaleConditionContract.deployed();
        console.log("\t\t[ SaleConditionContract address :: " + saleConditionContract.address + " ]");
        console.log("\t\t[ OfferContract address:: " + offerContract.address + " ]");
        console.log("\t\t[ Seller account address:: " + addressB + " ]");
        console.log("\t\t[ Buyer account address:: " + addressC + " ]");
        //console.log("\t\t[ accounts D address:: " + addressD + " ]");
        let isValid = saleConditionContract.create(offerContract.address);
        assert(offerContract !== undefined, 'has no OfferContract instance');
        assert.equal(isValid, true, 'OfferContract must be accepted by seller');

        //return true;
    }).timeout(100000);*/

    /*it("Are conditions met", async() => {
        await saleConditionContract.setConditionList(WallsPainted,CarpetCleaned,WindowsWashed);
        let isSatisfied = await saleConditionContract.isConditionMet();
        assert.equal(isSatisfied, true, "List of conditions must all be satisfied");
    }).timeout(100000);*/

});