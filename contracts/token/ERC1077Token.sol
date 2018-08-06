pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "../utils/LibBytes.sol";

/**
* @title ERC1077Token
* @dev Mintable ERC-20 token that implements ERC-1077 functionalities to allow
*      signature based function execution. EIP-1077 draft contains the necessary 
*      implementation details ; https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1077.md. 
*
* 
* Notes: 
*   - callPrefix & dataHash is replaced with _data
*   - to is removed (current contract) and added before from
*   - in operations ( create should be 2, not 0)
*   
*/
contract ERC1077Token is MintableToken {
  using LibBytes for bytes; 

  // Prefix that transaction must have            ERC-191    Version      from           to
  bytes constant TRANSACTION_PREFIX = abi.encode( byte(0x19), byte(0), address(this), address(this));

  // bytes4(keccak256("transferFrom(address,address,uint256,uint256,bytes)");
  bytes4 constant TRANSFERFROM_SIG = 0x23b872dd; 

  // bytes4(keccak256("setApprovalForAll(address,address,bool)"));
  bytes4 constant SETAPPROVALFORALL_SIG = 0x367605ca;

  // Transaction gas
  // uint256 constant _TRANSACTION_GAS = 100000; // 100,000 gas for transactions 


  // Transaction structure
  struct Transaction {
    uint256 value;       // Amount of Ether to be sent
    bytes data;          // Bytecode to be executed (function signature + encoded arguments)
    uint256 nonce;       // Signature nonce
    uint256 gasPrice;    // The gas price (paid in the selected token)
  //uint256 gasLimit;    // The the maximum gas to be paid
    address gasToken;    // Address of token to take to pay gas (leave 0 for ether)
  //Operation operation; // 0 for a standard call, 1 for a DelegateCall and 2 for a create opcode
    bytes extraData;     // Extra hash for forward compatibility
  }

  // Signature structure
  struct Signature {
    uint8   v;        // v variable from ECDSA signature.
    bytes32 r;        // r variable from ECDSA signature.
    bytes32 s;        // s variable from ECDSA signature.
    string sigPrefix; // Signature prefix message (e.g. "\x19Ethereum Signed Message:\n32");
  }

  // Operation that will be executed with transaction execution (in assembly)
  // enum Operation {
  //    Call,         // 0
  //    DelegateCall, // 1
  //    Create        // 2
  // }

  // Mappings
  mapping (address => mapping(address => bool)) operators; // Operators
  mapping (bytes4 => bool) allowedFunctions;        // Functions that can be called via ERC-1077

  // Events
  event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

  // Constructor
  constructor() {
    // Allowing certain functions to be called by ERC-1077 methods
    allowedFunctions[TRANSFERFROM_SIG]      = true;
    allowedFunctions[SETAPPROVALFORALL_SIG] = true;
  }

  // messages
  enum Error {
    INVALID_RECIPIENT,
    INVALID_SENDER,
    INVALID_SIGNATURE,
    EXECUTION_FAILED
  }


  //
  // Functions
  // 

  // ---------------------------------- //
  //           Modified ERC-20          //
  // ---------------------------------- //

  /**
  * @dev Transfer tokens from one address to another (OVERWRITTING ORIGINAL)
  * @param _from address The address which you want to send tokens from
  * @param _to address The address which you want to transfer to
  * @param _value uint256 the amount of tokens to be transferred
  */
  function transferFrom(address _from, address _to, uint256 _value)
    public returns (bool)
  {
    require(_to != address(0x0), 'INVALID_RECIPIENT');

    //Verifies whether sender is _from, an operator or this contract
    require(msg.sender == _from || operators[_from][msg.sender] || msg.sender == address(this), 'INVALID_SENDER');

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
  * @dev Will set _operator operator status to true or false
  * @param _from Token owner
  * @param _operator Address to changes operator status.
  * @param _approved _operator's new operator status (true or false)
  */
  function setApprovalForAll(address _from, address _operator, bool _approved) public {
    require(msg.sender == _from || msg.sender == address(this), 'INVALID_SENDER');

    // Update operator status
    operators[_from][_operator] = _approved;
    emit ApprovalForAll(_from, _operator, _approved);
  } 

  /**
  * @dev Function that verifies whether _operator is an authorized operator of _tokenHolder.
  * @param _operator The address of the operator to query status of
  * @param _owner Address of the tokenHolder
  * @return A uint256 specifying the amount of tokens still available for the spender.
  */
  function isApprovedForAll(address _owner, address _operator) external view returns (bool isOperator) {
    return operators[_owner][_operator];
  }



  // ---------------------------------- //
  //            ERC-1077                //
  // ---------------------------------- //


  /**
  * @dev Execute a function call on the behalf of a user
  * @param _transaction Transaction to execute
  * @param _sig Signature for the given transaction
  */ 
  function executeSignedTransaction(Transaction _transaction, Signature _sig) 
      public // Can't be `external` with solc 0.24 & ABIEncoderV2
  { 
    // Extract the _from argument from the transcation data (First function argument)
    // THIS WILL/SHOULD BE REPLACED BY https://github.com/ethereum/solidity/pull/4390
    address _from = _transaction.data.readAddress(4);

    // Verify if valid signature
    require(_from == recoverTransactionSigner(_transaction, _sig), 'INVALID_SIGNATURE');

    //Execute the call
    require( executeCall(_transaction.data), 'EXECUTION_FAILED' );
  }

  /**
  * @dev Execute the transaction based on the data passed
  * @param _data Transaction data
  *
  * Note: This executeCall function does not take 'to', 'value' since this implementation
  *       of ERC-1077 is tailored to a token contract.
  */
  function executeCall(bytes _data) 
      internal
      returns (bool success)
  { 

    address thisAddress = address(this);

    assembly { 
      // call( gas, contractToCall, value, input start, input length, output over input, output size)
      success := call(70000, thisAddress, 0x0, add(_data, 0x20), mload(_data), 0, 0)
    }

    return success;
  }

  /**
  * @dev return the transaction hash
  * @param _transaction Transaction struct containing the transaction information to hash
  */
  function getTransactionHash(Transaction _transaction)
      public pure returns (bytes32 transactionHash)
  {
    return  keccak256( abi.encode(TRANSACTION_PREFIX, _transaction) ); 
  }

  /**
  * @dev return signer of transaction hash
  * @param _transaction Transaction struct containing the transaction information to hash
  * @param _sig Signature structure containing the signature related variables
  * @return Return address of signer
  */
  function recoverTransactionSigner( 
    Transaction _transaction,
    Signature _sig)
    public view returns (address signer)
  { 
    // Hashing arguments
    bytes32 hash = getTransactionHash(_transaction);

    // If prefix provided, hash with prefix, else ignore prefix
    bytes32 prefixedHash = keccak256( abi.encodePacked(_sig.sigPrefix, hash) );

    // return signer recovered
    return recoverHashSigner(prefixedHash, _sig.r, _sig.s, _sig.v);
  }

  /**
  * @dev Returns the address of associated with the private key that signed _hash
  * @param _hash Hash that was signed.
  * @param _r r variable from ECDSA signature.
  * @param _s s variable from ECDSA signature.
  * @param _v v variable from ECDSA signature.
  * @return Address that signed the hash.
  */
  function recoverHashSigner(
      bytes32 _hash,
      bytes32 _r,
      bytes32 _s,
      uint8 _v)
      public pure returns (address signer)
  {
    // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
    if (_v < 27) {
      _v += 27;
    }

    // Recover who signed the hash
    signer = ecrecover( _hash, _v, _r, _s);

    // Makes sure signer is not 0x0. This is to prevent signer appearing to be 0x0.
    assert(signer != 0x0);

    // Return recovered signer address
    return signer;
  }

} 