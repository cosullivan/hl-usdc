import hre from "hardhat";
import { AbiCoder, ZeroAddress } from "ethers";
import { deployHyperCoreSim } from "hypercore-sim";
import {
  HLUSDC__factory,
  HLUSDCIssuer__factory,
  HLUSDCIssuerFactory__factory,
} from "../typechain-types";

export const deploymentFixture = async () => {
  const [signer, user2, user3] = await hre.ethers.getSigners();

  const { hyperCore, hyperCoreWrite } = await deployHyperCoreSim();

  await hyperCore.registerTokenInfo(0, {
    name: "USDC",
    spots: [],
    deployerTradingFeeShare: 0,
    deployer: ZeroAddress,
    evmContract: ZeroAddress,
    szDecimals: 8,
    weiDecimals: 8,
    evmExtraWeiDecimals: -2,
  });

  await hyperCore.forceAccountCreation(signer);

  const wusdcFactory = new HLUSDC__factory(signer);

  const wusdc = await wusdcFactory.deploy(signer);
  await wusdc.waitForDeployment();

  const wusdcIssuerFactoryFactory = new HLUSDCIssuerFactory__factory(signer);

  const wusdcIssuerFactory = await wusdcIssuerFactoryFactory.deploy(signer);
  await wusdcIssuerFactory.waitForDeployment();

  await wusdcIssuerFactory.setHLUSDC(wusdc);
  await wusdc.setIssuerFactory(wusdcIssuerFactory);

  const createIssuer = async () => {
    const transaction = await wusdcIssuerFactory.createIssuerAccount();
    const transactionReceipt = await transaction.wait();

    const address = AbiCoder.defaultAbiCoder().decode(
      ["address"],
      transactionReceipt!.logs[0]!.topics[1]
    );

    return HLUSDCIssuer__factory.connect(address[0], signer);
  };

  return {
    users: [signer, user2, user3],
    hyperCore,
    hyperCoreWrite,
    wusdc,
    wusdcIssuerFactory,
    createIssuer,
  };
};
