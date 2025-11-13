// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from
    "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8//interfaces/AggregatorV3Interface.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockFailedMintDsc} from "../mocks/MockFailedMintDsc.sol";

contract DSCEngineTest is Test {
    DecentralizedStableCoin public dsc;
    DSCEngine public dsce;
    HelperConfig public config;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerkey;

    address public USER = address(1);
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_TO_MINT = 100 ether;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerkey) = config.activeNetworkConfig();
        if (block.chainid == 31_337) {
            vm.deal(USER, STARTING_USER_BALANCE);
        }
        // Give users money
        ERC20Mock(weth).mint(USER, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_USER_BALANCE);
        // dsc.transferOwnership(address(dsce));
        console.log("Owner:", dsc.owner());
        console.log("DSCEngine:", address(dsce));
    }

    ///////////////////////
    // Constructor Test ///
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndpriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////
    // Price Test ///
    /////////////////
    function testGetUsdValue() public view {
        uint256 ethAmount = 20e18;

        uint256 expectedUsd = 40000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // $2000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    ////////////////////////////
    // depositCollateral Test //
    ////////////////////////////

    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(USER);
        //give the Collateral some weth
        ERC20Mock(weth).approve(USER, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock vanToken = new ERC20Mock("VAN", "VAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(vanToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    function testCanMintWithDepositedCollateral() public depositedCollateral {
        // Mint collateral to the user
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        // vm.prank(USER);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);

        // vm.prank(USER);
        // dsce.mintDsc(AMOUNT_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_TO_MINT);
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;

        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, totalCollateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    // MINTDSC TESTS ///

    function testCanMintDsc() public depositedCollateral {
        vm.startPrank(address(dsce));
        dsc.mint(USER, AMOUNT_TO_MINT);
        vm.stopPrank();
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_TO_MINT);
    }

    function testRevertsIfMintAmountIsZero() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }

    ////BURN TESTs ////

    function testRevertsIfBurnAmountIsZero() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testBurnDscRevertsIfZeroAmount() public {
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
    }

    function testBurnsDscRevertsNotAllowedToken() public {
        address tokenCollateralAddress = address(this);

        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(tokenCollateralAddress, AMOUNT_COLLATERAL);
    }

    function testBurnDscReducesTotalSupply() public depositedCollateralAndMintDsc() {
        vm.startPrank(address(dsce));

        uint256 startingTotalSupply = dsc.totalSupply();
        assertEq(startingTotalSupply, AMOUNT_TO_MINT);
        vm.stopPrank();
        
        vm.startPrank(USER);
        // // Act
        dsce.mintDsc(AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.burnDsc(AMOUNT_TO_MINT);

        //assert
        uint256 endingTotalSupply = dsc.totalSupply();
        assertEq(endingTotalSupply,  AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testCanBurnDsc() public depositedCollateral {
        vm.startPrank(USER);
        dsce.mintDsc(AMOUNT_TO_MINT);

        dsc.approve(address(dsce), AMOUNT_TO_MINT);
        dsce.burnDsc(AMOUNT_TO_MINT);

        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        dsce.burnDsc(1);
    }

    ////REDEEMCOLLATERAL TESTS//

    function testMintDscRevertsIfMintFails() public {
        // Arrange--setUp
        MockFailedMintDsc mockDsc = new MockFailedMintDsc();

        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        address owner = msg.sender;

        vm.prank(owner);
        DSCEngine mockEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockEngine));

        // approve transfer ot weth
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(mockEngine), AMOUNT_COLLATERAL);

        // Expect Revert from Dscengine
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        mockEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();
    }

    function testMintDscRevertsIfZeroAmount() public depositedCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
    }

    function testRedeemCollateralTransfersTokens() public {

        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);

        // Approve DSCEngine as USER
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        // Deposit collateral as USER
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        vm.startPrank(USER);
        uint256 userBalanceBeforeRedeem = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceBeforeRedeem, AMOUNT_COLLATERAL);

        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userBalanceAfterRedeem = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceAfterRedeem, 0);
        vm.stopPrank();
    }
    
    function testCanRedeemCollateral() public depositedCollateral{
        vm.startPrank(USER);
        uint256 userBalanceBeforeRedeem = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceBeforeRedeem, AMOUNT_COLLATERAL);
        
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userBalanceAfterCollateral = dsce.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceAfterCollateral, 0);
        vm.stopPrank();
    }

    //// HEALTH FACTOR TEST /////
    ////////////////////////////
    function testProperlyReportsHealthFactor() public depositedCollateralAndMintDsc {
        // Arrange
        uint256 expectedHealthFactor = 100 ether;
        uint256 userHealthFactor = dsce.getHealthFactor(USER);
        assertEq(userHealthFactor, expectedHealthFactor);
    }

    ///// LIQUIDATION TESTS /////

    //// LIQUIDATOR MODIFIER /////
    modifier liquidated() {
        // Let the user use Weth, deposit collateral and mint Dsc
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_TO_MINT);
        vm.stopPrank();

        // Update price to makee liquidation possible
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = dsce.getHealthFactor(USER);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dsce), collateralToCover);
        dsce.depositCollateralAndMintDsc(weth, collateralToCover, AMOUNT_TO_MINT);
        dsc.approve(address(dsce), AMOUNT_TO_MINT);

        require(userHealthFactor < 1e18, "User not liquidatable");

        dsce.liquidate(weth, USER, AMOUNT_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDscMinted,) = dsce.getAccountInformation(liquidator);
        assertEq(liquidatorDscMinted, AMOUNT_TO_MINT);
    }

    function testLiquidationPayoutIsCorrect() public liquidated {

        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = dsce.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT)
            + (dsce.getTokenAmountFromUsd(weth, AMOUNT_TO_MINT) * dsce.getLiquidationBonus() / dsce.getLiquidationPrecision());

        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    ///// VIEW AND PURE FUNCTION TEST /////
    function testGetDsc() public {
        address dscAddress = dsce.getDsc();
        assertEq(dscAddress, address(dsc));
    }

    function testGetHealthFactor() public {
        uint256 minHealthFactor = dsce.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = dsce.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValue() public {
        // Let the user Deposit some collateral
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        uint256 collateralValue = dsce.getAccountCollateralValue(USER);
        uint256 expectedCollateralValue = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);

        assertEq(collateralValue, expectedCollateralValue);
    }

    // VIEW & PURE FUNCTIONS TEST ////
    function testCollateralTokens() public {
        address[] memory collateralTokens = dsce.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetsHealthFaactor() public {
        uint256 healthFactor = dsce.getMinHealthFactor();
        assertEq(healthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetAccountCollateralValueInformation() public {
        (uint256 collateralValue, ) = dsce.getAccountInformation(USER);
        uint256 expectedCollateralValue = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);

        assertEq(collateralValue, expectedCollateralValue);
    }
}
