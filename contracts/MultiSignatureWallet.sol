pragma solidity ^0.5.0;

contract MultiSignatureWallet {

    struct Transaction {
      bool executed;
      address destination;
      uint value;
      bytes data;
    }
    
    address[] public owners ;
    uint public required ;
    
    // owners mapping which stores owner of multi-sig wallet
    mapping(address => bool) public isOwner ;
    
    uint public transactionCount ;
    
    // transactions mapping that stores a proposed Transaction 
    mapping(uint => Transaction) public transactions ;
    
    // confirmations mapping that stores a mapping of boolean values at owner addresses
    // keeps track of which owner addresses have confirmed which transactions.
    mapping (uint => mapping(address => bool)) public confirmations;
    
    // events
    event Deposit(address indexed sender, uint value);
    event Submission(uint indexed transactionId);
    event Confirmation(uint indexed transactionId, address indexed sender);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);

    /// @dev Fallback function allows to deposit ether.
    function()
    	external
        payable
    {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
	}
    }
    

    /*
     * Public functions
     */
    // Modifier to check that inputs are correct for constructor
    modifier validRequirement(uint ownerCount, uint _required) {
        if (_required > ownerCount || _required == 0 || ownerCount == 0)
            revert();
          _;
    } 
    
    
    
    /// @dev Contract constructor sets initial owners and required number of confirmations.
    /// @param _owners List of initial owners.
    /// @param _required Number of required confirmations.
    constructor(address[] memory _owners, uint _required) public validRequirement(_owners.length, _required){
        
        for(uint i=0; i<_owners.length; i++){
            isOwner[_owners[i]]=true;
        }
        
        owners = _owners;
        required = _required;
    }

    /// @dev Allows an owner to submit and confirm a transaction.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function submitTransaction(address destination, uint value, bytes memory data) public returns (uint transactionId) {
        
        // Check that the transaction sender is part of the Owners mapping
        require(isOwner[msg.sender]);
        
        // Add transaction to the transaction mapping
        transactionId = addTransaction(destination, value, data);
        
        // Submit the transaction for approval by the quorum
        confirmTransaction(transactionId) ;
    }

    /// @dev Allows an owner to confirm a transaction.
    /// @param transactionId Transaction ID.
    function confirmTransaction(uint transactionId) public {
        // check that the caller is a wallet owner
        require(isOwner[msg.sender] == true) ;
        
        // check that the transaction (transactionId) exists
        require(transactions[transactionId].destination != address(0));
        
        // check that the caller has not already confirmed the transaction
        require(confirmations[transactionId][msg.sender] == false);
        
        // else => confirm transaction 
        confirmations[transactionId][msg.sender] == true;
        
        // Since we are modifying the state in this function, it is a good practice to log an event
        emit Confirmation(transactionId, msg.sender);
        
        //call executeTransaction function
        executeTransaction(transactionId);
    }

    /// @dev Allows an owner to revoke a confirmation for a transaction.
    /// @param transactionId Transaction ID.
    function revokeConfirmation(uint transactionId) public {}

    /// @dev Allows anyone to execute a confirmed transaction.
    /// @param transactionId Transaction ID.
    function executeTransaction(uint transactionId) public {
        // check that the transaction has not already been executed
        require(transactions[transactionId].executed == false);
        
        // check that it is confirmed by the required quorum
        if(isConfirmed(transactionId)==true){
            // execute
            Transaction storage t = transactions[transactionId];  // using the "storage" keyword makes "t" a pointer to storage 
            t.executed = true;
            (bool success, bytes memory returnedData) = t.destination.call.value(t.value)(t.data);
            if (success)
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                t.executed = false;
            }
        }
    }

		/*
		 * (Possible) Helper Functions
		 */
    /// @dev Returns the confirmation status of a transaction.
    /// @param transactionId Transaction ID.
    /// @return Confirmation status.
    function isConfirmed(uint transactionId) internal view returns (bool) {
        
        // loop through owners mapping and check how many have confirmed the given transaction
        uint count = 0 ;
        for(uint i=0; i < owners.length; i++){
            if(confirmations[transactionId][owners[i]] == true)
                count += 1;
            if(count==required)
                return true; 
        }
        
    }

    /// @dev Adds a new transaction to the transaction mapping, if transaction does not exist yet.
    /// @param destination Transaction target address.
    /// @param value Transaction ether value.
    /// @param data Transaction data payload.
    /// @return Returns transaction ID.
    function addTransaction(address destination, uint value, bytes memory data) internal returns (uint transactionId) {
        
        //Get the transactionCount
        transactionId = transactionCount;
        
        // Store transaction in the transactions mapping
        transactions[transactionId] = Transaction({
            destination: destination, 
            value: value, 
            data: data,
            executed : false
        });
        
        // Increment the transactionCount
        transactionCount += 1 ;
        
        // Emit the Submission event
        emit Submission(transactionId);
    }
}
