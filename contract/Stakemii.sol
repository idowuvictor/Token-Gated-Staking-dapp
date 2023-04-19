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

contract Stakemii{

    uint constant rate = 3854;
    uint256 constant factor = 1e11;
    address owner;
    uint stakeNumber;

    address constant cUSDAddress = 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;
    address constant CELOAddress = 0xF194afDf50B03e69Bd7D057c1Aa9e10c9954E4C9;
    address constant cEURAddress = 0x10c892A6EC43a53E45D0B916B4b7D383B1b78C0F;
    address constant cREALAddress = 0xC5375c73a627105eb4DF00867717F6e301966C32;

    uint public cEURAddressTotalstaked;
    uint public cREALAddressTotalstaked;
    uint public CELOAddressTotalstaked;
    uint public cUSDAddressTotalstaked;

    constructor(){
        owner = msg.sender;
    }

    mapping(address => mapping(address => uint256)) private stakes;



    struct stakeInfo{
        address staker;
        address tokenStaked;
        uint amountStaked;
        uint timeStaked;
        address[] tokenaddress;
    }

    modifier addressCheck(address _tokenAddress){
        require(_tokenAddress != address(0), "Invalid Address");
        _;
    }

    modifier acceptedAddress(address _tokenAddress){
        require( _tokenAddress == cUSDAddress || _tokenAddress == CELOAddress || _tokenAddress == cEURAddress || _tokenAddress == cREALAddress, "TOKEN NOT ACCEPTED");
        _;
    }
    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }


    mapping(address => mapping(address => stakeInfo)) public usersStake;
    mapping(address => address[]) public tokensAddress;

    event stakedSuccesful(address indexed _tokenaddress, uint indexed _amount);
    event withdrawsuccesfull(address indexed _tokenaddress, uint indexed _amount);

    function stake (address _tokenAddress, uint _amount) public addressCheck(_tokenAddress) acceptedAddress(_tokenAddress) {
        require(IERC20(cUSDAddress).balanceOf(msg.sender) > 2 ether, "User does not have a Celo Token balance that is more than 3");
        require(IERC20(_tokenAddress).balanceOf(msg.sender) > _amount, "insufficient balance");
        require(_amount > 0, "Amount should be greater than 0");
        require(_tokenAddress != address(0), "Token address cannot be 0x0");


         IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(msg.sender);
        require(balance >= _amount, "Insufficient balance");


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

         stakes[msg.sender][_tokenAddress] = _amount;


       emit stakedSuccesful(_tokenAddress, _amount);
    }


    function withdraw(address _tokenAddress, uint _amount) public addressCheck(_tokenAddress) acceptedAddress(_tokenAddress){
        stakeInfo storage ST = usersStake[msg.sender][_tokenAddress];
        //require(ST.timeStaked > 0, "You have no staked token here");
        require(_amount <= ST.amountStaked , "insufficient balance");
        require(_amount > 0, "Amount should be greater than 0");


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
