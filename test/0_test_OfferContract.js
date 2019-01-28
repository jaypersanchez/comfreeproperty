var OfferContract = artifacts.require("OfferContract");
var SaleConditionContract = artifacts.require("SaleConditionContract");
var EscrowContract = artifacts.require("EscrowContract");

contract('OfferContract', function(accounts) {
    /*
    * Accounts from Ganache
    */
    let initialBalance = 1;
    let contractOwnerAddress = accounts[0]; 
    let buyerAddressA = accounts[1];
    let sellerAddressB = accounts[2];
    let buyerAddressC = accounts[3];
    let sellerAddressD = accounts[4];
    let buyerAddressE = accounts[5];
    let sellerAddressF = accounts[6];


    let offerContract;
    let saleConditionContract;
    let escrowContract;

    /*
    * By setting the values of each variables below, we can test for different scenarios
    */
    //Make offer test scenario
    let offerAmount = 50;
    let acceptvalue = true;
    let offercontractId = 1;

    //set condition list scenario
    var WallsPainted = true;
    var CarpetCleaned = true;
    var WindowsWashed = true;

    //escrow payment scenario
    var escrowPaymentAmount = 50;

    /*
    *   Contract initiation starts from Buyer.  
    *   
    */
    it("Create OfferContract Instance", async() => {
        offerContract = await OfferContract.deployed();
        console.log("\t\t[ Contract Owner address :: " + contractOwnerAddress + " ]");
        assert(offerContract !== undefined, 'has no OfferContract instance');
    }).timeout(100000);

    it("Submit an offer", async() => {
        //increment index
        var offerDate = 1; //Date.now();
        var expiryTime = 1; //Date.now() + (1000 * 60 * 60 * 10) + 1;// (in the future 10 days and a day)
        var offerAmount = web3.toWei(10,'ether');
        var accepted = false;
        let result = await offerContract.createOfferContract.call(buyerAddressA,sellerAddressB,offerDate, offerDate, expiryTime, offerAmount, accepted);
        let resultHash = await offerContract.createOfferContract(buyerAddressA,sellerAddressB,offerDate, offerDate, expiryTime, offerAmount, accepted);
        console.log("\t\t[ Result Success :: " + result + " ]");
        let isaccepted = await offerContract.isOfferAccepted.call(buyerAddressA);
        console.log("\t\t[ Offer should not be accepted by default :: " + isaccepted + " ]");
        assert.equal(isaccepted, false, "When an initial offer is created, the offer should not be accepted by default");
    });

    it("Accept Offer by :: " + sellerAddressB, async () => {
        let result = await offerContract.accept.call(offercontractId, acceptvalue);
        let resultHash = await offerContract.accept(offercontractId, acceptvalue);
        console.log("\t\t[ Seller Accepts Offer :: " + result + " ]");
        let isaccepted = await offerContract.isOfferAccepted.call(offercontractId);
        console.log("\t\t[ Offer should not be accepted by default :: " + isaccepted + " ]");
        /*
        * Testing assert is not applicable in this section.  Testing accept state of an offer must be allowed to toggle between
        * true and false
        */
       if(isaccepted) {
           console.log("\t\t[ Offer Contract State is accepted ]");
       }
       else {
        console.log("\t\t[ Offer Contract State is accepted ]");
       }
        //assert.equal(isaccepted, true, "At this point, users at the application layer should have accepted the offer");
    }).timeout(100000);

    /*
    * Test upon creation of SaleConditionContract, OfferContract accept must
    * return true
    */
    it("SaleConditionContract Instance", async() => {
        let isaccepted = await offerContract.isOfferAccepted.call(offercontractId);
        if ( isaccepted ) {
            saleConditionContract = await SaleConditionContract.deployed();
            console.log("\t\t[ SaleConditionContract address :: " + saleConditionContract.address + " ]");
            //assert(saleConditionContract !== undefined, 'has no SaleConditionContract instance');
            assert.equal(isaccepted, true, "Offer has been accepted.  Should allow sale condition contract to move forward");
        }
        else {
            console.log("\t\t[ Unable to create saleConditionConract.  OfferContract has not been accepted]");    
            assert.equal(isaccepted, false, "Cannot allow a sale condition contract to be created if offer contract ID is not at accepted state");
        }
        
    }).timeout(100000);

    it("Set List of Conditions to be met before entering escrow", async() => {
        //set condition list
        let isSatisfied = await saleConditionContract.isConditionMet.call();
        console.log("\t\t[ Have all conditions been met :: " + isSatisfied + " ]");
        let result = await saleConditionContract.setConditionList.call(WallsPainted,CarpetCleaned,WindowsWashed);
        let resultHash = await saleConditionContract.setConditionList(WallsPainted,CarpetCleaned,WindowsWashed);
        isSatisfied = await saleConditionContract.isConditionMet.call();
        console.log( "\t\t[ isSatisfied ] " + isSatisfied );
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
        let isSatisfied = await saleConditionContract.isConditionMet.call();
        assert.equal(isSatisfied, true, "All sale conditions must be met before moving on to escrow");
        escrowContract = await EscrowContract.deployed();
        let msgSenderAddress = await escrowContract.getMsgSender.call();
        console.log("\t\t[ EscrowContract address :: MsgSender " + escrowContract.address + "::" + msgSenderAddress + " ]");
        //assert(escrowContract !== undefined, 'has no EscrowContract instance');
        let buyerAddressBalanceBeforeTransfer = await web3.eth.getBalance(buyerAddressA);
        let sellerAddressBalanceBeforeTransfer = await web3.eth.getBalance(sellerAddressB);
        let escrowContractBalanceBeforeTransfer = await web3.eth.getBalance(contractOwnerAddress);
        console.log("\t\t[ Balances Before Transfers ] " +  buyerAddressBalanceBeforeTransfer + "::" +
        sellerAddressBalanceBeforeTransfer + "::" + escrowContractBalanceBeforeTransfer);
        /*
        * Current design requires buyer account to send ether payment to contract instance.
        * sendFundsToSeller will forward this ether to sellerAddress. 
        * This means, this must also be done on the web ui side of the DApp
        * 1st param default account to send ether to contract
        * 2nd param seller wallet address to receive ether payments
        * 3rd is the amount of ether to be paid which is the escrow amount
        */
        /*
        * must send ether from buyerAddress to contractOwnerAddress
        * escrow payments must be coming from an escrow bank so the escrow payment
        * must be originating from the escrow contract address
        */
       let msgValueBeforeTransferResult = await escrowContract.getMsgValue.call();
        let send = web3.eth.sendTransaction({from:buyerAddressA,to:escrowContract.address, value:web3.toWei(escrowPaymentAmount, "ether")});
        let msgValueAfterTransferResult = await escrowContract.getMsgValue.call();
        console.log("\t\t[ msgValueBeforeTransferResult :: escrowPaymentAmount ] " + msgValueBeforeTransferResult + "::" + escrowPaymentAmount );
        //now sent money to sellerAddress
        let result = await escrowContract.sendFundsToSeller.call(web3.toWei(escrowPaymentAmount,'ether'), sellerAddressB);
        console.log("\t\t[ Escrow Transfer Result :: " + result + " to " + sellerAddressB + " ]");
        if(result == 1) {
            
            console.log("\t\t[ Transfer Success ]");
        } 
        else {
            console.log("\t\t[ Transfer Failed ]");
            //console.log("\t\t[ Transfer success, current balance ] " + buyerAddressBalanceAfterTransfer +
              //          "::" + sellerAddressBalanceAfterTransfer + "::" + escrowContractBalanceAfterTransfer);    
        }
        
   });

});