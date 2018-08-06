const BigNumber = web3.BigNumber;
const Web3Utils = require('web3-utils');
const fromRpcSig = require('ethereumjs-util').fromRpcSig;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

// Token
const ERC1077TokenMock = artifacts.require('ERC1077Token');

// Addres 0x0
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

// bytes4(keccak256("transferFrom(address,address,uint256,uint256,bytes)");
const TRANSFERFROM_SIG = 0x23b872dd; 

// bytes4(keccak256("setApprovalForAll(address,address,bool)"));
const SETAPPROVALFORALL_SIG = 0x367605ca;

contract('ERC1077-Token', function ([_, owner, sender, operator]) { 
  context('When contract are deployed', function () {
    beforeEach(async function () {
      this.token = await ERC1077TokenMock.new({from: owner});
      //console.log(web3.eth.getTransactionReceipt(this.token.transactionHash).gasUsed);
    });

    describe('executeCall Function', async function () {


    })



  })

})