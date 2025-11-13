🪙 Decentralized Stablecoin (DSC)

A minimal, collateral-backed, algorithmically-stable decentralized stablecoin pegged to the USD.

📘 Overview

The Decentralized Stablecoin (DSC) system maintains a stable value by allowing users to deposit collateral (like ETH or BTC) and mint DSC tokens pegged to USD.
It combines over-collateralization, Chainlink oracles, and liquidation mechanisms to maintain solvency and stability without centralized control.

🧩 Core Architecture
Component	Description
DecentralizedStableCoin.sol	ERC20 implementation of the DSC token. Minted/burned by the DSCEngine only.
DSCEngine.sol	Core logic layer handling deposits, minting, burning, redemptions, and liquidations.
OracleLib.sol	A safety wrapper for Chainlink price feeds with staleness checks.
Mocks (ERC20Mock, MockV3Aggregator)	Used in Foundry tests to simulate collateral and price feeds.
⚙️ System Flow

Deposit Collateral → Lock ETH/BTC equivalents.

Mint DSC → Borrow DSC up to a safe collateral ratio.

Burn DSC → Repay debt to unlock collateral.

Liquidation → If health factor < 1, liquidators redeem undercollateralized positions.

🧠 Key Concepts
Term	Explanation
Health Factor	Ensures a user's position remains overcollateralized (> 1e18).
Liquidation Threshold	Collateral-to-debt ratio below which liquidation can occur.
Liquidation Bonus	Incentive (e.g., 10%) for liquidators who stabilize the system.
Price Feeds	Chainlink oracles providing live ETH/USD and BTC/USD prices.
🧰 Project Structure
src/
├── DecentralizedStableCoin.sol     # ERC20 implementation
├── DSCEngine.sol                   # Core engine for mint/burn/liquidation
├── libraries/
│   └── OracleLib.sol               # Oracle safety checks
test/
├── unit/
│   ├── DSCEngineTest.t.sol         # Unit tests for DSCEngine logic
│   └── DecentralizedStableCoinTest.t.sol
└── integration/
    └── DSCEngineIntegration.t.sol  # Full flow tests (deposit, mint, liquidate)
script/
├── DeployDSC.s.sol                 # Foundry deploy script
└── HelperConfig.s.sol              # Config for testnets/local

⚙️ Setup & Deployment
1️⃣ Prerequisites

Foundry

Git, Node.js (optional for frontend integration)

2️⃣ Clone Repository
git clone https://github.com/<sharon-dev-create>/decentralized-stablecoin.git
cd decentralized-stablecoin

3️⃣ Install Dependencies
forge install

4️⃣ Build Contracts
forge build

5️⃣ Run Tests
forge test -vvv


Add -vvvv for detailed trace logs (recommended when debugging reverts).

🧪 Testing Scenarios
Test	Description
testCanDepositCollateral	Verifies user deposits collateral successfully.
testCanMintDsc	Ensures minting is proportional to deposited collateral.
testBurnDscReducesTotalSupply	Confirms burning DSC decreases total supply.
testLiquidatorTakesOnUsersDebt	Simulates liquidation when a user’s health factor drops below 1.
testRedeemCollateral	Checks user collateral redemption logic.

Run a single test:

forge test --match-test testLiquidatorTakesOnUsersDebt -vvvv

🧮 Example Health Factor Calculation
healthFactor = (collateralValueInUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION)
                * PRECISION / totalDscMinted;


If healthFactor < 1e18, user is eligible for liquidation.

🧱 Deployment (Optional)

To deploy locally:

forge script script/DeployDSC.s.sol --broadcast --rpc-url http://127.0.0.1:8545


To deploy on a testnet (e.g., Sepolia):

forge script script/DeployDSC.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv

🧭 Future Improvements

✅ Add multi-collateral support (DAI-style model)

🔐 Integrate a governance module for parameter tuning

📊 Build a frontend dashboard for monitoring collateral health

🧰 Add fuzz & invariant tests for robustness


👤 Author
Sharon Emmanuel (Topgg)
Solidity & Blockchain Developer
💻 Passionate about building decentralized financial systems.
🌐 GitHub https://github.com/sharon-dev-create
 • Twitter @named_sharon