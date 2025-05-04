import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  //defaultNetwork: "hardhat",
  // networks: {
  //   testnet: {
  //     url: "https://rpc.hyperliquid-testnet.xyz/evm",
  //     accounts: [process.env.PRIVATE_KEY!],
  //     chainId: 998,
  //     forking: {
  //       url: "https://rpc.hyperliquid-testnet.xyz/evm",
  //     },
  //   },
  //   mainnet: {
  //     url: "https://rpc.hyperliquid.xyz/evm",
  //     accounts: [process.env.PRIVATE_KEY!],
  //     chainId: 999,
  //   },
  // },
};

export default config;
