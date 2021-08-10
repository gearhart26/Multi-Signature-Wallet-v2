pragma solidity 0.7.5;
    //allows us to return a struct from functions
pragma abicoder v2;

contract Multi_Sig_Wallet_v2 {
        
        //Variable to hold contract creator and number of required votes
    address [] private owners;
    uint votesNeeded;
    
        //Constructor to set contract owners and number of required votes
    constructor(address[] memory _owners, uint _votesNeeded){
        require(_owners.length >= _votesNeeded, "Not enough _owners for selected number of _votesNeeded");
        require(_votesNeeded >= 1, "Number of _votesNeeded cannot be 0");
        owners = _owners;
        votesNeeded = _votesNeeded;
    }
    
        //Double mapping for owner transaction approvals 
    mapping(address => mapping(uint => bool)) hasVoted;
        
        //Modifier to set owner permissions
    modifier onlyOwners(){
       bool owner = false;
            //Iterating through owners list and checking each against msg.sender.
            //If msg.sender is in owners list then owner variable set to true and function is executed after require
       for (uint i=0; i<owners.length; i++){
           if (owners[i] == msg.sender){
               owner = true;
           }
       }
       require(owner == true);
        _;
    }
   
         //Empty array to hold transfers that have been proposed by owners
    Transaction[] private transactionRequests;
    
        //Mapping that allows us to call transactions by their ID
    mapping (uint => Transaction) private transactions;
        
        //A variable that will increment and  be assigned to transactions as they are submitted
    uint private TransactionID;
        
        //Empty array to hold transfer IDs for each transfer
    uint[] private transactionIdList;
        
        //Balance mapping
    mapping(address => uint) balance;

        //Struct to hold transaction information, total yes votes, and who has voted for each transaction
    struct Transaction {
        uint transactionID;
        address submitted_by;
        address payable recipient;
        uint amount;
        uint total_approval_votes;
        bool sent;
    }

        //Events to signify a deposit, new transaction request, new vote being cast by owner, and transaction execution
    event newDeposit (address from, uint Amount);
    event newTransactionRequest (uint TransactionId, address SubmittedBy, address Recipient, uint Amount);
    event newTransactionApproval (address VotingOwner, uint TransactionId, uint CurrentYesVotes);
    event transactionExecuted (uint TransactionId, address Sender, address Recipient, uint Amount);
            
        //Deposit function
    function deposit() public payable returns(uint) {
        balance[msg.sender] += msg.value;
        emit newDeposit(msg.sender, msg.value);
        return(balance[msg.sender]);
    }
        
        //Individual amount deposited
    function getYourContribution() public view returns(uint) {
        return(balance[msg.sender]);
    }
        
        //Total balance held by smart contract 
    function getTotalBalance() public view returns(uint) {
        return(address(this).balance);
    }
        
        //Function for owners to look at array of all pending transaction objects and all of their variables at once
    function getTransactions() public view onlyOwners returns(Transaction[] memory) {
        return(transactionRequests);
    }
        
         //For owners to quickly look at array of only pending transaction ID numbers
    function getTxIdList() public view onlyOwners returns(uint[] memory) {
        return(transactionIdList);
    }
        
        //Function that only allows owners to propose transactions
    function proposeTransaction(address payable _recipient, uint _amount) public onlyOwners{
            //Checking required funds, checking owner is not recipent, & incrementing transaction ID
        require((address(this).balance) >= _amount, "Insufficient funds");
        require (msg.sender != _recipient, "Cannot send funds to Owners");
        uint _transactionID = TransactionID++;
            //Building transaction 
        Transaction memory _transaction;
        _transaction.transactionID = _transactionID;
        _transaction.total_approval_votes = 0;
        _transaction.submitted_by = msg.sender;
        _transaction.recipient = _recipient;
        _transaction.amount = _amount;
        _transaction.sent = false;
            //Saving to memory and emitting event
        transactions[_transactionID] = _transaction;
        transactionIdList.push(_transactionID);
        transactionRequests.push(_transaction);
        emit newTransactionRequest(_transactionID, msg.sender, _recipient, _amount);
    }
        
        //Allows owners to give approval for transactions by ID number
    function approveTransaction(uint _transactionId) public onlyOwners {
            //Requiring owner has not already voted for this transaction and it has not yet been sent
        require(hasVoted[msg.sender][_transactionId] == false, "Vote has already been cast");
        require(transactionRequests[_transactionId].sent == false, "Transaction has already been sent");
            //Updating total_approval_votes and hasVoted mapping
        hasVoted[msg.sender][_transactionId] = true;
        transactionRequests[_transactionId].total_approval_votes++;
        emit newTransactionApproval (msg.sender, _transactionId, transactionRequests[_transactionId].total_approval_votes);
        
                //If new vote makes total_approval_votes >= votesNeeded and the contract balance is still >= amount then the transaction is executed
            if (transactionRequests[_transactionId].total_approval_votes >= votesNeeded){
                require(address(this).balance >= transactionRequests[_transactionId].amount, "Insufficient funds");
                transactionRequests[_transactionId].sent = true;
                transactionRequests[_transactionId].recipient.transfer(transactionRequests[_transactionId].amount);
                emit transactionExecuted (_transactionId, transactionRequests[_transactionId].submitted_by, transactionRequests[_transactionId].recipient, transactionRequests[_transactionId].amount);
            }  
    }
}
