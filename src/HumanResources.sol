// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;


import "./IHumanResources.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISwapRouter.sol";
//import "https://github.com/Uniswap/v3-periphery/blob/v1.0.0/contracts/interfaces/ISwapRouter.sol";
//https://goerli.optimism.io
//https://mainnet.optimism.io

interface IWETH is IERC20 {
    // Withdraw WETH to get ETH
    function withdraw(uint256 amount) external;
}


contract HumanResources is IHumanResources {
    address public immutable hrManager; //hr manager address once set cannot be modify
    mapping(address => Employee) private employees;
    uint256 private activeEmployeeCount; //count of active employee
    AggregatorV3Interface internal immutable priceFeed;
    ISwapRouter internal immutable uniswap;
    IWETH internal immutable WETH;
    IERC20 public immutable USDC;

    //employee information storage
    struct Employee {uint256 weeklyUsdSalary;//18 decimals
        uint256 employedSince;
        uint256 terminatedAt;
        bool isEth; //USDC in default
        uint256 lastPaid;
        uint256 unclaimUSD; //salary unclaimed for previous employment period
    }
    modifier onlyhrManager() {
        require (msg.sender == hrManager, NotAuthorized());
        _;
    }
    constructor() {
        hrManager = msg.sender;
        priceFeed = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);
        uniswap = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        WETH = IWETH(0x4200000000000000000000000000000000000006); // WETH address
        USDC = IERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85); // USDC address
    }
    //to register employee, can only be called by hr manager
    function registerEmployee(address employee, uint256 weeklyUsdSalary) external onlyhrManager(){
        Employee storage emp = employees[employee];
        //can only register non-register employee
        require(emp.employedSince == 0 || emp.terminatedAt > 0, EmployeeAlreadyRegistered());
        emp.weeklyUsdSalary = weeklyUsdSalary; //modify the struct 
        emp.employedSince =  block.timestamp; //start new employment time
        emp.terminatedAt= 0;  //not terminated
        emp.isEth = false; //reset to usdc
        emp.lastPaid = block.timestamp;  //new accumalation for salary time
        activeEmployeeCount ++;
        emit EmployeeRegistered(employee, weeklyUsdSalary);
    }
    //to terminate employee, can only be called by hr manager
    function terminateEmployee(address employee) external onlyhrManager(){
        Employee storage emp = employees[employee];
        require (emp.employedSince > 0 && emp.terminatedAt == 0, EmployeeNotRegistered()); //only active employee
        emp.terminatedAt = block.timestamp;
        emp.unclaimUSD = salaryAvailableUSD(employee); //sum up the salary into USD
        activeEmployeeCount --;
        emit EmployeeTerminated(employee);
    }
    function getActiveEmployeeCount() external view returns (uint256){
        return activeEmployeeCount; //number of active employee
    }
    function getEmployeeInfo(address employee) external view 
        returns (uint256 weeklyUsdSalary,uint256 employedSince,uint256 terminatedAt)
    {//return information of employee
        Employee storage emp = employees[employee];
        weeklyUsdSalary = emp.weeklyUsdSalary;
        employedSince = emp.employedSince; 
        terminatedAt = emp.terminatedAt;
        return (weeklyUsdSalary, employedSince, terminatedAt);
    }//if no such employee return all 0

   //get eth price
    function getETHPrice() public view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();//get price
        require(price > 0, "Invalid ETH price");
        uint256 feedDecimals = priceFeed.decimals();
        uint256 ethPrice = uint256(price)* (10 ** (18 - feedDecimals)) ;//into suitable decimals
        return (uint256(ethPrice));
    }

    //calculate the salary available in employee's prefered currency
    function salaryAvailable(address employee) public view returns (uint256){
        Employee storage emp = employees[employee];
        uint256 weeklyPay = emp.weeklyUsdSalary;
        uint256 lastPayTime = emp.lastPaid;
        // now if active or previos terminate time if terminated
        uint256 endTime = emp.terminatedAt > 0 ? emp.terminatedAt : block.timestamp;
        // time span to pay in terms of sec for new period
        uint256 elapsedTime = endTime - lastPayTime; 
        //accumalted salary in usd for the new period
        uint256 accPayInUSD = (elapsedTime * weeklyPay) / 604800; 

        // calculate accumalated salary including previous unclaimed in prefered currency
        if (emp.isEth == false){//if USDC 
            accPayInUSD += emp.unclaimUSD;
            uint256 accPayInUSDC = (accPayInUSD / 1e12);
            return accPayInUSDC;
        } else {// if eth
            uint256 totalPayInUSD = (accPayInUSD+emp.unclaimUSD);
            uint256 ethPrice = getETHPrice();
            uint256 accPayInEth = (totalPayInUSD*1e18/ethPrice); //swapping usd to eth
            return accPayInEth; 
            }
    }
    //calculate accumulated salary in terms of USD (similar to above code but in Usd, easier to use)
    function salaryAvailableUSD(address employee) public view returns (uint256){
        Employee storage emp = employees[employee];                            
        uint256 weeklyPay = emp.weeklyUsdSalary;
        uint256 lastPayTime = emp.lastPaid;
        // now if active or previos terminate time if terminated
        uint256 endTime = emp.terminatedAt > 0 ? emp.terminatedAt : block.timestamp;
        uint256 elapsedTime = endTime - lastPayTime;
        uint256 accPayInUSD = (elapsedTime * weeklyPay) / 604800;
        accPayInUSD += emp.unclaimUSD;
        return accPayInUSD;
    }
    //withdraw salary in prefered currency
    function withdrawSalary() public {
        Employee storage emp = employees[msg.sender];
        require(emp.employedSince > 0, NotAuthorized());
        uint256 salaryUSD = salaryAvailableUSD(msg.sender);
        uint256 salaryInPrefer = salaryAvailable(msg.sender);
        require(salaryUSD > 0, "No salary available");
        //avoid reentrance
        emp.unclaimUSD = 0;
        emp.lastPaid = block.timestamp;

        // Handle payment in the employee's preferred currency
        if (emp.isEth) {
           swapUSDCtoETHAndPay(msg.sender, salaryUSD,salaryInPrefer); // Swap USDC to ETH and transfer
        } else {
            //uint256 USDCInput = salaryUSD / 1e12;
            bool success =  IERC20(USDC).transfer(msg.sender, salaryInPrefer); // Transfer USDC directly
            require(success, "USDC transfer failed");
        }
        emit SalaryWithdrawn(msg.sender, emp.isEth, salaryUSD);
    }
    //to swap exact usdc into eth and transfer to employee
    function swapUSDCtoETHAndPay(address recipient, uint256 salaryInUSD,uint256 salaryInPrefer) internal {
      // assign the expected ETH amount
       uint256 expectedEth = salaryInPrefer;
      // Set the minimum ETH amount out, protect against front-running slippage
       uint256 minEthOut = (expectedEth * 98) / 100;
      // Calculate the Exact USDC input
       uint256 USDCInput = salaryInUSD / 1e12;

      // Define Uniswap swap parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
           tokenIn: address(USDC),
           tokenOut: address(WETH),
           fee: 500, // Uniswap 0.05% pool fee
           recipient: address(this), // Contract temporarily holds WETH
           deadline: block.timestamp + 300, // 5 minute
           amountIn: USDCInput, // Exact amount of USDC needed
           amountOutMinimum: minEthOut, // Minimum eth allowed for the swap
           sqrtPriceLimitX96: 0 
        });

      // Approve the Uniswap router to spend USDC
       IERC20(USDC).approve(address(uniswap), USDCInput);
      // Perform the swap
       uint256 IWETHOutput = uniswap.exactInputSingle(params);
      // Ensure ETH received meets the minimum threshold
       require(IWETHOutput >= minEthOut, "Slippage exceeded");
      // Convert WETH to ETH
       WETH.withdraw(IWETHOutput);

      // Transfer ETH to the recipient
       (bool success, ) = recipient.call{value: IWETHOutput}("");
       require(success, "ETH transfer failed");
    }
    receive() external payable {
    }
    // switch prefered currency of employee and withdraw any unclaim salary before the switch
    function switchCurrency() public {
        Employee storage emp = employees[msg.sender];
        require(emp.employedSince > 0 && emp.terminatedAt == 0, NotAuthorized());//requrie to be active emp

        if (salaryAvailable(msg.sender) != 0){
            withdrawSalary();//skip process if there is no salary to be transfered to reduce gas
        }
        emit CurrencySwitched(msg.sender,emp.isEth);
        emp.isEth = !emp.isEth;//switch of prefered currency
    }
}


