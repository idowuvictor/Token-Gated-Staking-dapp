// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC20{
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);

}

// Beginning of the contract
contract Stakemii{
    
    //constant rate of return on the staked used to calculate interest
    uint constant rate = 3854;

    // Factor for interest calculation
    uint256 constant factor = 1e11;

    //Adding owner address
    address owner;

    //Amount Staked
    uint stakeNumber;

    //Addresses for stakeable currencies
    address constant cUSDAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;
    address constant CELOAddress = 0xF194afDf50B03e69Bd7D057c1Aa9e10c9954E4C9;
    address constant cEURAddress = 0x10c892A6EC43a53E45D0B916B4b7D383B1b78C0F;
    address constant cREALAddress = 0xC5375c73a627105eb4DF00867717F6e301966C32;

    // Totals of each currency staked
    uint public cEURAddressTotalstaked;
    uint public cREALAddressTotalstaked;
    uint public CELOAddressTotalstaked;
    uint public cUSDAddressTotalstaked;

    //constructor Initializing Contract by setting the sender of the initial transaction as contract owner
    constructor(){
        owner = msg.sender;
    }

    /* 
    
    Struct that stores staking info;
      *Address of the staker
      *Token address of the token staked
      *Amount to stake
      *Time of the staking event

    */

    struct stakeInfo{
        address staker;
        address tokenStaked;
        uint amountStaked;
        uint timeStaked;
        
    }
    
    // Checks that a token address is not a zero Address
    modifier addressCheck(address _tokenAddress){
        require(_tokenAddress != address(0), "Invalid Address");
        _;
    }
    
    //Check that currency address is one of the accepted addresses for staking
    modifier acceptedAddress(address _tokenAddress){
        require( _tokenAddress == cUSDAddress || _tokenAddress == CELOAddress || _tokenAddress == cEURAddress || _tokenAddress == cREALAddress, "TOKEN NOT ACCEPTED");
        _;
    }

    //Modifier check for only owner callable functions
    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }

    //Maps Users addresses to a mapping of currency address and stake info
    mapping(address => mapping(address => stakeInfo)) public usersStake;

    //Maps User addresses to those of the tokens they have staked
    mapping(address => address[]) public tokensAddress;
    
    //Two events emitted upon succesfull staking action and withdrawal of stake by user 
    event stakedSuccesful(address indexed _tokenaddress, uint indexed _amount);
    event withdrawsuccesfull(address indexed _tokenaddress, uint indexed _amount);

    /*

      Function to stake into the contract

      ->Requirements
        * Token Address should be one of the accepted addresses and cannot be a zero address
        * Token balance of the sender should be greater than the amount they wish to stake.
        * User should have a cUSD balance greater than 2
        * function then transfers amount user has specified to the contract
        * User then updates the User token address mapping with the users staking info 

    */

    function stake (address _tokenAddress, uint _amount) public addressCheck(_tokenAddress) acceptedAddress(_tokenAddress) {
        require(IERC20(cUSDAddress).balanceOf(msg.sender) > 2 ether, "User does not have a Celo Token balance that is more than 3");
        require(IERC20(_tokenAddress).balanceOf(msg.sender) > _amount, "insufficient balance");
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount );
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];
        if(ST.amountStaked > 0){
            uint interest = _interestGotten(_tokenAddress);
            ST.amountStaked += interest;
        }
        ST.staker = msg.sender;
        ST.amountStaked = _amount;
        ST.tokenStaked = _tokenAddress;
        ST.timeStaked = block.timestamp;
        tokensAddress[msg.sender].push(_tokenAddress);

        stakeNumber +=1;

        if(_tokenAddress == cEURAddress){
            cEURAddressTotalstaked += _amount;
        } else if(_tokenAddress == cUSDAddress){
           cUSDAddressTotalstaked += _amount;
        } else if(_tokenAddress == CELOAddress){
            CELOAddressTotalstaked += _amount;
        }else{
            cREALAddressTotalstaked += _amount;
        }

       emit stakedSuccesful(_tokenAddress, _amount);
    }

    /*
       Function for the withdrawal of the stake
       
       ->Requirements
       *None zero and accepted token address for the staked token.
       *Amount requested in withdrawal is not greater than balance (staked amount and the interest)
       *Amount to withdraw cannot be zero

    */
    function withdraw(address _tokenAddress, uint _amount) public addressCheck(_tokenAddress) acceptedAddress(_tokenAddress){
        require(_amount > 0, "Cannot withdraw Zero amount");

        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];

        //require(ST.timeStaked > 0, "You have no staked token here");

        uint interest = _interestGotten(_tokenAddress);

        require(_amount <= ST.amountStaked + interest, "insufficient balance");
        
        ST.amountStaked -= _amount;

        IERC20(_tokenAddress).transfer(msg.sender, _amount);

        IERC20(cUSDAddress).transfer(msg.sender, interest);

        emit withdrawsuccesfull(_tokenAddress, _amount);
    }

    /*
    *function to calculate interest on the stake
    Checks if staked amount is not zero and calculates interest

    -> Requirements

    */
    function _interestGotten(address _tokenAddress) internal view returns(uint ){
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];

        uint interest;

        if(ST.amountStaked > 0){
            uint time = block.timestamp - ST.timeStaked;
            uint principal = ST.amountStaked;
            interest = principal * rate * time;
            interest /=  factor;
        }
        return interest;
    }
    
    //Function to show the user how much interest they have generated
    function showInterest(address _tokenAddress) external view acceptedAddress(_tokenAddress) returns(uint){
        uint interest = _interestGotten(_tokenAddress);
        return interest;
    }
    
    //Function to show the user how much of each token they have staked
    function amountStaked(address _tokenAddress) external view acceptedAddress(_tokenAddress) returns(uint){
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];
        return  ST.amountStaked;
    }
    
    //Function returns the number of stakes made.
    function numberOfStakers() public view returns(uint){
        return stakeNumber;
    }
    // Returns list of all tokens a given address has invested.
    function getAllTokenInvested() external view returns(address[] memory){
       return tokensAddress[msg.sender];
    }
    
    //Function for emergency withdrawal of funds from contract for a given token in the event of an exploit or update

    /*
    ->Requirments
      *Caller should be the owner of the contract

    */

    function emergencyWithdraw(address _tokenAddress) external onlyOwner{
       uint bal = IERC20(_tokenAddress).balanceOf(address(this));
       IERC20(_tokenAddress).transfer(msg.sender, bal);
    }


}
