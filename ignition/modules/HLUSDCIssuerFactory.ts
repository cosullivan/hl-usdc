// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import "dotenv/config"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

const OWNER_ADDRESS = process.env.OWNER_ADDRESS
if (!OWNER_ADDRESS) throw new Error("OWNER_ADDRESS is not set")

const HLUSDCIssuerFactoryModule = buildModule("HLUSDCIssuerFactoryModule", (m) => {
  const hlusdcIssuerFactory = m.contract("HLUSDCIssuerFactory", [OWNER_ADDRESS])

  return { hlusdcIssuerFactory }
})

export default HLUSDCIssuerFactoryModule
