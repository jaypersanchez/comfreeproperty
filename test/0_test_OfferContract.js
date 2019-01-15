var OfferContract = artifacts.require("OfferContract");
var SaleConditionContract = artifacts.require("SaleConditionContract");
var EscrowContract = artifacts.require("EscrowContract");

contract('OfferContract', function(accounts) {
    /*
    * Accounts from Ganache
    */
    let initialBalance = 1;
    let buyerAddress = accounts[0];
    let sellerAddress = accounts[1];
    var addressB = accounts[2];
    var addressC = accounts[3];

    let offerContract;
    let saleConditionContract;
    let escrowContract;
    let offerAmount = 50;
    let accept = true;

    //condition list
    var WallsPainted = true;
    var CarpetCleaned = true;
    var WindowsWashed = true;

    /*
    *   Contract initiation starts from Buyer.  
    *   
    */

    it("OfferContract Instance", async() => {
        offerContract = await OfferContract.deployed();
        console.log("\t\t[ OfferContract address :: " + offerContract.address + " ]");
        console.log("\t\t[ Coinbase Buyer account address:: " + buyerAddress + " ]");
        console.log("\t\t[ Seller account address:: " + sellerAddress + " ]");
        
        assert(offerContract !== undefined, 'has no OfferContract instance');
    }).timeout(100000);


    it("Set Seller Wallet Address :: " + sellerAddress, async () => {
        await offerContract.setSellerAddress(sellerAddress);
        let sellerAddy = await offerContract.getSellerAddress.call();
        assert.equal(sellerAddy, sellerAddress, "Seller Address does not match with what was setup");
    }).timeout(100000);

    it("Set Buyer Wallet Address :: " + buyerAddress, async () => {
        await offerContract.setBuyerAddress(buyerAddress);
        let buyerAddy = await offerContract.getBuyerAddress.call();
        assert.equal(buyerAddy, buyerAddress, "Buyer Address does not match with what was setup");
    }).timeout(100000);

    it("Set Buyer Offer", async() => {
        await offerContract.setBuyerOffer(offerAmount);
        let offeredAmount = await offerContract.getOfferAmount.call();
        assert.equal(offerAmount, offeredAmount,"Amount offered does not equal with offer on record");
    }).timeout(100000);

    it("Buyer offer accepted", async() => {
        let _accept = await offerContract.accept(accept);
        let isaccepted = await offerContract.isOfferAccepted.call();
        assert.equal(isaccepted, true, 'Offer not accepted.  Will not initiate Sale Condition contract');
        if(isaccepted) {
            console.log("\t\t[ Offer accepted ]");
        }
        else {
            console.log("\t\t[ Error: Offer Not accepted ]");
        }
        //assert.equal(_accept, isaccepted,"Offer does not match what is on record");
    }).timeout(100000);

    /*
    *   Test upon creation of SaleConditionContract, OfferContract accept must
    * return true
    */

    it("SaleConditionContract Instance", async() => {
        let isaccepted = offerContract.isOfferAccepted.call();
        if ( isaccepted ) {
            saleConditionContract = await SaleConditionContract.deployed();
            //saleConditionContract = new SaleConditionContract(offerContract.address);
            console.log("\t\t[ SaleConditionContract address :: " + saleConditionContract.address + " ]");
            assert(saleConditionContract !== undefined, 'has no SaleConditionContract instance');
        }
        else {
            console.log("\t\t[ Unable to create saleConditionConract.  OfferContract has not been accepted]");    
        }
        
    }).timeout(100000);

    it("Are conditions met", async() => {
        //set condition list
        await saleConditionContract.setConditionList(WallsPainted,CarpetCleaned,WindowsWashed);
        let isSatisfied = await saleConditionContract.isConditionMet.call();
        console.log( "\t\t[ isSatisfied ] " + isSatisfied );
        //assert(saleConditionContract !== undefined, 'has no SaleConditionContract instance');
        //assert.equal(isSatisfied, true, "List of conditions must all be satisfied");
        if(isSatisfied) {
            console.log("\t\t[ All sale conditions are met ]");
        }
        else {
            console.log("\t\t[ Error: All sale conditions must be met ]");
        }
    }).timeout(100000);

    /*
    *   Test EscrowContract, should not be created until sale condition list from
    * SaleConditionContract is met
    */
   it("Create EscrowContract", async() => {
        escrowContract = await EscrowContract.deployed();
        console.log("\t\t[ EscrowContract address :: " + escrowContract.address + " ]");
        assert(escrowContract !== undefined, 'has no EscrowContract instance');
        let buyerAddressBalanceBeforeTransfer = await web3.eth.getBalance(buyerAddress);
        let sellerAddressBalanceBeforeTransfer = await web3.eth.getBalance(sellerAddress);
        let escrowContractBalanceBeforeTransfer = await web3.eth.getBalance(escrowContract.address);
        console.log("\t\t[ Balances Before Transfers ] " + buyerAddressBalanceBeforeTransfer + "::" +
        sellerAddressBalanceBeforeTransfer + "::" + escrowContractBalanceBeforeTransfer);
        /*
        * Current design requires buyer account to send ether payment to contract instance.
        * sendFundsToSeller will forward this ether to sellerAddress. 
        * This means, this must also be done on the web ui side of the DApp
        * 1st param default account to send ether to contract
        * 2nd param seller wallet address to receive ether payments
        * 3rd is the amount of ether to be paid which is the escrow amount
        */
        let result = await escrowContract.sendFundsToSeller(web3.toWei(10,'ether'), sellerAddress, {value: web3.toWei(20,'ether')});
        if(result !== 1) {
            //transfer failed
            console.log("\t\t[ Transfer failed ]");
        } 
        else {
            //success transfer
            var buyerAddressBalanceAfterTransfer = await web3.eth.getBalance(buyerAddress);
            var sellerAddressBalanceAfterTransfer = await web3.eth.getBalance(sellerAddress);
            var escrowContractBalanceAfterTransfer = await web3.eth.getBalance(escrowContract.address);
            console.log("\t\t[ Transfer success, current balance ] " + buyerAddressBalanceAfterTransfer +
                        "::" + sellerAddressBalanceAfterTransfer + "::" + escrowContractBalanceAfterTransfer);    
        }
        //console.log("Account Balance After " + buyerAddress + "::" + sellerAddress);
   });

});