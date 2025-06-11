// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/// @notice You may need to change these import statements depending on your project structure and where you use this test
import {Test, console, stdStorage, StdStorage} from "forge-std/Test.sol";
import {HumanResources, IHumanResources} from "../src/HumanResources.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "../src/interfaces/AggregatorV3Interface.sol";

contract HumanResourcesTest is Test {
    using stdStorage for StdStorage;

    address internal constant _WETH =
        0x4200000000000000000000000000000000000006;
    address internal constant _USDC =
        0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    AggregatorV3Interface internal constant _ETH_USD_FEED =
        AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    HumanResources public humanResources;

    address public hrManager;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public cora = makeAddr("cora");// not a employee


    uint256 public aliceSalary = 2100e18;
    uint256 public bobSalary = 700e18;
    uint256 public coraSalary = 0;

    uint256 ethPrice;

    function setUp() public {
    
      string memory rpc = vm.envString("RPC_URL");
      address hrContractAddress = vm.envAddress("HR_CONTRACT");//import contract address
      vm.createSelectFork(rpc);//creat fork for testing
      humanResources = HumanResources(payable(hrContractAddress));

        (, int256 answer, , , ) = _ETH_USD_FEED.latestRoundData();
        uint256 feedDecimals = _ETH_USD_FEED.decimals();
        ethPrice = uint256(answer) * 10 ** (18 - feedDecimals); //get eth price with suitable decimals
        hrManager = humanResources.hrManager();
    }

    function test_registerEmployee() public {
        _registerEmployee(alice, aliceSalary);
        assertEq(humanResources.getActiveEmployeeCount(), 1);//check for register employee and employee count

        uint256 currentTime = block.timestamp;
        (
            uint256 weeklySalary,
            uint256 employedSince,
            uint256 terminatedAt
        ) = humanResources.getEmployeeInfo(alice);
        assertEq(weeklySalary, aliceSalary);
        assertEq(employedSince, currentTime);
        assertEq(terminatedAt, 0);//check for function getEmplyeeInfo

        skip(10 hours);

        _registerEmployee(bob, bobSalary);

        (weeklySalary, employedSince, terminatedAt) = humanResources
            .getEmployeeInfo(bob);
        assertEq(humanResources.getActiveEmployeeCount(), 2);// check count for active employee

        assertEq(weeklySalary, bobSalary);
        assertEq(employedSince, currentTime + 10 hours);
        assertEq(terminatedAt, 0);//check for active employee info
    }

    // function registerEmployee should revert when call by non-HR manager
    function test_registerEmployee_notAuthorized() public {
        vm.prank(alice);// called by an employee instead of hr manager
        vm.expectRevert(IHumanResources.NotAuthorized.selector); //revert not authorized
        humanResources.registerEmployee(alice, aliceSalary);
    }
    // register the same employee twice without termination should revert
    function test_registerEmployee_twice() public {
        _registerEmployee(alice, aliceSalary);// first time
        vm.expectRevert(IHumanResources.EmployeeAlreadyRegistered.selector); //revert 
        _registerEmployee(alice, aliceSalary);//second time
    }
      // terminate the same employee twice without re-registration should revert
    function test_terminateEmployee_twice() public {
        _registerEmployee(alice, aliceSalary);

        vm.prank(hrManager);
        humanResources.terminateEmployee(alice);//first termination

        vm.prank(hrManager);
        vm.expectRevert(IHumanResources.EmployeeNotRegistered.selector);//revert
        humanResources.terminateEmployee(alice);//second termination
    }
    // terminate employee should revert for non-hr manager
    function test_terminateEmployee_notAuthorized() public {
        _registerEmployee(alice, aliceSalary);

        vm.prank(cora); //termination not called by hr manager
        vm.expectRevert(IHumanResources.NotAuthorized.selector); //revert
        humanResources.terminateEmployee(alice);
    }
    // employee info should return all 0 for unregistered address
    function test_getEmployeeInfo_unregistered() view public {
        (uint256 weeklySalary, uint256 employedSince, uint256 terminatedAt) 
        = humanResources.getEmployeeInfo(cora);//a unregistered address
        assertEq(weeklySalary, 0); 
        assertEq(employedSince, 0);
        assertEq(terminatedAt, 0);
    }

    // check salaryAvailable function for usdc preference
    function test_salaryAvailable_usdc() public {
        _registerEmployee(alice, aliceSalary);
        skip(2 days);
        assertEq(
            humanResources.salaryAvailable(alice),
            ((aliceSalary / 1e12) * 2) / 7 //checking after 2 days
        );

        skip(5 days); //another check after 5 days
        assertEq(humanResources.salaryAvailable(alice), aliceSalary / 1e12);
    }
    // check salaryAvailable function for eth preference including a switch before any withdraw
    function test_salaryAvailable_eth() public {
        _registerEmployee(alice, aliceSalary);
        uint256 expectedSalary = (aliceSalary * 1e18 * 2) / ethPrice / 7;
        vm.prank(alice);
        humanResources.switchCurrency();// switch to eth
        skip(2 days);
        assertApproxEqRel( //salary for 2days
            humanResources.salaryAvailable(alice),
            expectedSalary,
            0.01e18
        );
        skip(5 days);
        expectedSalary = (aliceSalary * 1e18) / ethPrice;
        assertApproxEqRel( //salary accumulated including previous unclaim
            humanResources.salaryAvailable(alice),
            expectedSalary,
            0.01e18
        );
    }

    //check withdrawsalary function for usdc preference
    function test_withdrawSalary_usdc() public {
        _mintTokensFor(_USDC, address(humanResources), 10_000e6);
        _registerEmployee(alice, aliceSalary);
        skip(2 days);
        vm.prank(alice);
        humanResources.withdrawSalary();
        assertEq(
            IERC20(_USDC).balanceOf(address(alice)),
            ((aliceSalary / 1e12) * 2) / 7
        );

        skip(5 days);
        vm.prank(alice);
        humanResources.withdrawSalary();
        assertEq(IERC20(_USDC).balanceOf(address(alice)), aliceSalary / 1e12);
    }
    //check withdrawsalary function for usdc preference including a switch at the start
    function test_withdrawSalary_eth() public {
        _mintTokensFor(_USDC, address(humanResources), 10_000e6);
        _registerEmployee(alice, aliceSalary);
        uint256 expectedSalary = (aliceSalary * 1e18 * 2) / ethPrice / 7;
        vm.prank(alice);
        humanResources.switchCurrency();
        skip(2 days);
        vm.prank(alice);
        humanResources.withdrawSalary();
        assertApproxEqRel(alice.balance, expectedSalary, 0.01e18);
        skip(5 days);
        expectedSalary = (aliceSalary * 1e18) / ethPrice;
        vm.prank(alice);
        humanResources.withdrawSalary();
        assertApproxEqRel(alice.balance, expectedSalary, 0.01e18);
    }
    //re-register employee including a termination in between
    function test_reregisterEmployee() public {
        _mintTokensFor(_USDC, address(humanResources), 10_000e6);
        _registerEmployee(alice, aliceSalary);
        skip(2 days);
        vm.prank(hrManager);
        humanResources.terminateEmployee(alice);
        skip(1 days);
        _registerEmployee(alice, aliceSalary * 2);

        skip(5 days);
        vm.prank(alice);
        humanResources.withdrawSalary();
        uint256 expectedSalary = ((aliceSalary * 2) / 7) +
            ((aliceSalary * 2 * 5) / 7);//salary should should include previous unclaim
        assertEq(
            IERC20(_USDC).balanceOf(address(alice)),
            expectedSalary / 1e12
        );
    }
    // withdraw should revert if not called by employee
    function test_withdraw_notAuthorized() public {
        _registerEmployee(alice, aliceSalary);

        vm.prank(cora);
        vm.expectRevert(IHumanResources.NotAuthorized.selector);
        humanResources.withdrawSalary();
    }
    // switch currency should revert if not called by active employee
    function test_switchCurrency_notAuthorized() public {
        // unregistered user tries to switch
        vm.prank(bob);
        vm.expectRevert(IHumanResources.NotAuthorized.selector);
        humanResources.switchCurrency();//revert

        // terminated employee tries to switch
        _registerEmployee(alice, aliceSalary);
        vm.prank(hrManager);
        humanResources.terminateEmployee(alice);//terminated
        vm.prank(alice);
        vm.expectRevert(IHumanResources.NotAuthorized.selector);
        humanResources.switchCurrency();//revert 
    }
    function _registerEmployee(address employeeAddress, uint256 salary) public {
        vm.prank(hrManager);
        humanResources.registerEmployee(employeeAddress, salary);
    }

    function _mintTokensFor(
        address token_,
        address account_,
        uint256 amount_
    ) internal {
        stdstore
            .target(token_)
            .sig(IERC20(token_).balanceOf.selector)
            .with_key(account_)
            .checked_write(amount_);
    }
    
}
