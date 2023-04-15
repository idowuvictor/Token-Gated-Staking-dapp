// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract Stakemii {
    // Constants for interest rate and calculation factor
    uint constant rate = 3854;
    uint256 constant factor = 1e11;

    // Contract owner and stake number counter
    address owner;
    uint stakeNumber;

    // Constants for token addresses
    address constant cUSDAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;
    address constant CELOAddress = 0xF194afDf50B03e69Bd7D057c1Aa9e10c9954E4C9;
    address constant cEURAddress = 0x10c892A6EC43a53E45D0B916B4b7D383B1b78C0F;
    address constant cREALAddress = 0xC5375c73a627105eb4DF00867717F6e301966C32;

    // Total amount staked for each token
    uint public cEURAddressTotalstaked;
    uint public cREALAddressTotalstaked;
    uint public CELOAddressTotalstaked;
    uint public cUSDAddressTotalstaked;

    constructor(){
        owner = msg.sender;
    }

    struct stakeInfo {
        address staker;
        address tokenStaked;
        uint amountStaked;
        uint timeStaked;
        address[] tokenaddress;
    }

    // Modifier to check if the provided address is not zero
    modifier addressCheck(address _tokenAddress){
        require(_tokenAddress != address(0), "Invalid Address");
        _;
    }

    // Modifier to check if the provided token address is accepted
    modifier acceptedAddress(address _tokenAddress){
        require( _tokenAddress == cUSDAddress || _tokenAddress == CELOAddress || _tokenAddress == cEURAddress || _tokenAddress == cREALAddress, "TOKEN NOT ACCEPTED");
        _;
    }

    // Modifier to check if the caller is the contract owner
    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }

    mapping(address => mapping(address => stakeInfo)) public usersStake;
    mapping(address => address[]) public tokensAddress;

    event stakedSuccesful(address indexed _tokenaddress, uint indexed _amount);
    event withdrawsuccesfull(address indexed _tokenaddress, uint indexed _amount);

    // Function to stake tokens
    function stake (address _tokenAddress, uint _amount) public addressCheck(_tokenAddress) acceptedAddress(_tokenAddress) {
        // Check if user has enough cUSD balance to stake
        require(IERC20(cUSDAddress).balanceOf(msg.sender) > 2 ether, "User does not have a Celo Token balance that is more than 3");
        // Check if user has enough balance of the token to be staked
        require(IERC20(_tokenAddress).balanceOf(msg.sender) > _amount, "insufficient balance");
        // Transfer tokens from user to contract
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount );
        stakeInfo storage ST = users
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


    function withdraw(address _tokenAddress, uint _amount) public addressCheck(_tokenAddress) acceptedAddress(_tokenAddress){
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];
        //require(ST.timeStaked > 0, "You have no staked token here");
        require(_amount <= ST.amountStaked , "insufficient balance");
        uint interest = _interestGotten(_tokenAddress);
        ST.amountStaked -= _amount;
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
        IERC20(cUSDAddress).transfer(msg.sender, interest);

        emit withdrawsuccesfull(_tokenAddress, _amount);
    }


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

    function showInterest(address _tokenAddress) external view acceptedAddress(_tokenAddress) returns(uint){
        uint interest = _interestGotten(_tokenAddress);
        return interest;
    }

    function amountStaked(address _tokenAddress) external view acceptedAddress(_tokenAddress) returns(uint){
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];
        return  ST.amountStaked;
    }

    function numberOfStakers() public view returns(uint){
        return stakeNumber;
    }

    function getAllTokenInvested() external view returns(address[] memory){
       return tokensAddress[msg.sender];
    }

    function emergencyWithdraw(address _tokenAddress) external onlyOwner{
       uint bal = IERC20(_tokenAddress).balanceOf(address(this));
       IERC20(_tokenAddress).transfer(msg.sender, bal);
    }


}
