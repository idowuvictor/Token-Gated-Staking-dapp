// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//IERC20 Interface
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

     /// @dev constructor Initializing Contract by setting the sender of the initial transaction as contract owner
    constructor(){
        owner = msg.sender;
    }


     /**
     * @notice  . Struct that stores staking info;
     * @param   staker  . Address of the staker
     * @param   tokenStaked  . Token address of the token staked
     * @param   amountStaked  . Amount staked
     * @param   timeStaked  . Time of stake
     */
    struct stakeInfo{
        address staker;
        address tokenStaked;
        uint amountStaked;
        uint timeStaked;
    }


    //*******************Modifier******************** */
    // checks for address zero
    modifier addressCheck(address _tokenAddress){
        require(_tokenAddress != address(0), "Invalid Address");
        _;
    }

    //  checks that the user is staking the accepted token
    modifier acceptedAddress(address _tokenAddress){
        require( _tokenAddress == cUSDAddress || _tokenAddress == CELOAddress || _tokenAddress == cEURAddress || _tokenAddress == cREALAddress, "TOKEN NOT ACCEPTED");
        _;
    }

    // checks for ownwer/adamin
    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }


    mapping(address => mapping(address => stakeInfo)) public usersStake;
    mapping(address => address[]) public tokensAddress;

    //***************** EVENTS **********************/
    event stakedSuccesful(address indexed _tokenaddress, uint indexed _amount);
    event withdrawsuccesfull(address indexed _tokenaddress, uint indexed _amount);


    /**
     * @notice  . Users are require to have balance of 2 cUSD
     * @dev     . A function to stake
     * @param   _tokenAddress  . The Address of the token to be staked
     * @param   _amount  . The amount to be staked
     */
    function stake (address _tokenAddress, uint _amount) public addressCheck(_tokenAddress) acceptedAddress(_tokenAddress) {
        require(_amount > 0, "Amount should be greater than 0");
        require(IERC20(cUSDAddress).balanceOf(msg.sender) > 2 ether, "User does not have a Celo Token balance that is more than 3");
        require(IERC20(_tokenAddress).balanceOf(msg.sender) > _amount, "insufficient balance");
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount );
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];
        if(ST.amountStaked > 0){
            uint interest = _interestGotten(_tokenAddress);
            ST.amountStaked += interest;
            ST.amountStaked += (ST.amountStaked * interest) / factor;
        }
        ST.staker = msg.sender;
        ST.amountStaked += _amount;
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


    /**
     * @dev     . A function to withdraw stake
     * @param   _tokenAddress  . The Address of the token to be withdraw
     * @param   _amount  . The amount to withdraw
     */
    function withdraw(address _tokenAddress, uint _amount) public addressCheck(_tokenAddress) acceptedAddress(_tokenAddress){
        require(_amount > 0, "Amount should be greater than 0");
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];
        require(ST.amountStaked > 0, "You have no staked for this token");
        require(_amount <= ST.amountStaked , "insufficient balance");
        uint interest = _interestGotten(_tokenAddress);
        ST.amountStaked -= _amount;
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
        IERC20(cUSDAddress).transfer(msg.sender, interest);
        stakeNumber -=1;
        emit withdrawsuccesfull(_tokenAddress, _amount);
    }


     /**
     * @notice  . An internal function to get interest on amount staked
     * @dev     . A function to get interest
     * @param   _tokenAddress  . The Address of the token to get interest for
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
    
    
     /**
     * @dev     . A view function to show interest gotten
     * @param   _tokenAddress  . The Address of the token to get interest for
     */
    function showInterest(address _tokenAddress) external view acceptedAddress(_tokenAddress) returns(uint){
        uint interest = _interestGotten(_tokenAddress);
        return interest;
    }

     /**
     * @dev     . A view function to get amount staked for a token address
     * @param   _tokenAddress  . The Address of the token to get amount staked
     */
    function amountStaked(address _tokenAddress) external view acceptedAddress(_tokenAddress) returns(uint){
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];
        return  ST.amountStaked;
    }

    /**
     * @dev     . A view function to get total number of stakers
     */
    function numberOfStakers() public view returns(uint){
        return stakeNumber;
    }
    
    /**
     * @dev     . A view function to get the token(address) a user has staken
     */
    function getAllTokenInvested() external view returns(address[] memory){
       return tokensAddress[msg.sender];
    }
    
    /**
     * @notice  . Can only be called by the deployer of the contract.
     * @dev     . A view function to withdraw locked funds
      * @param   _tokenAddress  . The Address of the token to withdraw 
     */
    function emergencyWithdraw(address _tokenAddress) external onlyOwner{
       uint bal = IERC20(_tokenAddress).balanceOf(address(this));
       IERC20(_tokenAddress).transfer(msg.sender, bal);
    }


}
