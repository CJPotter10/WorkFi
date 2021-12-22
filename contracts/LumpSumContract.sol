//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract LumpSumContract {

    // declare events
    event TransactionSubmitted(uint transactionID);
    event Deposit(address indexed sender, uint value);
    event Confirmation(address indexed sender, uint indexed transactionId);
    event Submission(uint indexed transactionId);
    event Revocation(address indexed sender, uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    // Declare constants


    // Declare mappings/storage
    mapping (uint => Transaction) public transactions;
    mapping (uint => mapping (address => bool)) public confirmations;
    
    address payable public client;
    address payable public serviceProvider;
    address payable public BlockerrDAO;
    uint public required = 2;
    uint public transactionCount = 0;
    address[] users;

    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool executed;
    }

    //modifiers
    modifier onlyWallet() {
        require(msg.sender == address(this));
        _;
    }

    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].destination != address(0x0));
        _;
    }

    modifier confirmed(uint transactionId, address _owner) {
        require(confirmations[transactionId][_owner]);
        _;
    }

    modifier notConfirmed(uint transactionId, address _owner) {
        require(!confirmations[transactionId][_owner]);
        _;
    }

    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed);
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0x0));
        _;
    }

    modifier onlyClient() {
        require(msg.sender == client);
        _;
    }

    modifier onlyServiceProvider() {
        require(msg.sender == serviceProvider);
        _;
    }

    modifier isValidUser(address _address) {
        require(msg.sender == client || msg.sender == serviceProvider || msg.sender == address(this) || msg.sender == BlockerrDAO);
        _;
    }

    // Function that allows for ether to be deposited
    function deposit() payable public {
        if(msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    constructor(address payable _client, address payable _serviceProvider, address payable _DAO) {
        client  = _client;
        users.push(client);
        serviceProvider = _serviceProvider;
        users.push(_serviceProvider);
        BlockerrDAO = _DAO;
        users.push(_DAO);
    }

    // function to change the wallet associated with the client
    function changeClient(address payable _newClient)
        onlyClient
        public
        notNull(_newClient)
    {
        client = _newClient;
    }

    function changeServiceProvider(address payable _newProvider) 
        onlyServiceProvider
        notNull(_newProvider)
        public
    {
        serviceProvider = _newProvider;
    }

    function addTransaction(address destination, uint value, bytes memory data)
        internal
        notNull(destination)
        returns (uint transactionId)
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }

    function approveTransaction(uint transactionId)
        public
        isValidUser(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    function revokeApproval(uint transactionId)
        public
        isValidUser(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }

    function submitTransaction(address payable destination, uint value, bytes memory data)
        public 
        returns (uint transactionId)
    {
        transactionId = addTransaction(destination, value, data);
        approveTransaction(transactionId);
    }

    function executeTransaction(uint transactionId)
        public
        isValidUser(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        if(isConfirmed(transactionId)) {
            Transaction storage txn = transactions[transactionId];
            txn.executed = true;
            if(external_call(payable(txn.destination), txn.value, txn.data.length, txn.data)) {
                emit Execution(transactionId);
            } else {
                emit ExecutionFailure(transactionId);
                txn.executed = false;
            }
        }
    }

    function isConfirmed(uint transactionId)
        public
        view
        returns (bool result)
    {
        uint count = 0;
        for (uint i = 0; i < 3;) {
            result = false;
            if(confirmations[transactionId][users[i]]) {
                count += 1;
            }
            if(count == required){
                result = true;
            }
        }
        return result;
    }

    function external_call(address payable destination, uint value, uint dataLength, bytes memory data) internal returns (bool) {
        bool result;
        assembly {
            let x := mload(0x40)
            let d := add(data, 32)
            result := call(
                sub(gas(),34710),
                destination,
                value,
                d,
                dataLength,
                x,
                0
            )
        }
        return result;
    }


    


}