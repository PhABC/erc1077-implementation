pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import '../token/ERC1077Token.sol';

contract ERC1077TokenMock is ERC1077Token {

  uint256 constant INIT_SUPPLY = 1000000000000000;

  constructor() public { 
    balances[msg.sender] = INIT_SUPPLY;
  }


}
