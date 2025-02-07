// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether; // 0.1 * 10 ** 18
    uint256 constant STARTING_BALANCE = 10 ether; // startBalance
    uint256 constant GAS_PRICE = 1; // gasPrice，gas费的价格

    // 运行测试文件的时候，会先运行setUp函数，再运行测试函数，然后再运行setUp函数，然后再运行测试函数
    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() external view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() external view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
        // assertEq(version, 6);
    }
    
    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // 预期失败，下一行会回滚，触发 require 或 revert
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // The next TX will be send by USER
        fundMe.fund{value: SEND_VALUE}();    
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER); // The next TX will be send by USER
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        // 先用user用户存款 modifier funded

        // 然后用user用户取款
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithDrawWithASingleFunder() public funded {
        // Arrange，安排测试，设置测试环境
        uint256 startingOwnerBalance = fundMe.getOwner().balance; // 合约所有者Owner的余额
        uint256 startingFunderBalance = address(fundMe).balance; // 存款前的余额

        // Act, Action，执行我想要的测试操作
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // uint256 gasUsed = (gasStart - gasEnd) * GAS_PRICE;

        // Assert，断言
        uint256 endingOwnerBalance = fundMe.getOwner().balance; // 合约所有者Owner的余额 + 存款前的余额
        uint256 endingFunderBalance = address(fundMe).balance; // 存款后的余额，为0了，钱已经存进去了
        assertEq(endingFunderBalance, 0);
        assertEq(endingOwnerBalance, startingOwnerBalance + startingFunderBalance);
    }

    function testWithDrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10; // 10个用户
        uint160 startingFunderIndex = 1; // 从第一个用户开始取款
        // 遍历所有的funder，并为其提供存款
        for (uint160 i = startingFunderIndex; i <= numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance; // 合约所有者Owner的余额
        uint256 startingFunderBalance = address(fundMe).balance; // 存款前的余额

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw(); // 取款
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(fundMe.getOwner().balance == startingOwnerBalance + startingFunderBalance);
    }
}