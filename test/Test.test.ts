import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { deploymentFixture } from "./deploymentFixture";
import { scale } from "./utils";

describe("HL-USDC", function () {
  it("succeeds when mininting", async function () {
    const { users, wusdc, hyperCore, hyperCoreWrite, createIssuer } =
      await loadFixture(deploymentFixture);

    // force the spot amount on HyperCore
    await hyperCore.forceSpot(users[0], 0, scale(10, 8));

    // we are minting via user0 but using user1 as the destination
    // so ensure that there is no balance for now
    expect(await wusdc.balanceOf(users[1])).eq(0);

    const issuer = await createIssuer();

    await hyperCoreWrite.connect(users[0]).sendSpot(issuer, 0, scale(10, 8));
    await hyperCoreWrite.flushActionQueue();

    expect(await hyperCore.readSpotBalance(issuer, 0)).deep.eq([
      scale(10, 8),
      0n,
      0n,
    ]);

    await issuer.initiateMintRequest(scale(10, 8));
    await hyperCoreWrite.flushActionQueue();

    await issuer.completeMint(users[1]);
    await hyperCoreWrite.flushActionQueue();

    // the mint should transfer the supply to user1
    expect(await wusdc.balanceOf(users[1])).eq(scale(10, 6));

    // ensure there is no spot balance remaining on the issuer
    expect(await hyperCore.readSpotBalance(issuer, 0)).deep.eq([0n, 0n, 0n]);

    // the full spot amount now exists on the wusdc account as backing
    expect(await hyperCore.readSpotBalance(wusdc, 0)).deep.eq([
      scale(10, 8),
      0n,
      0n,
    ]);
  });

  it("succeeds when redeeming", async function () {
    const { users, wusdc, hyperCore, hyperCoreWrite, createIssuer } =
      await loadFixture(deploymentFixture);

    // force the spot amount on HyperCore
    await hyperCore.forceSpot(users[0], 0, scale(10, 8));

    // set up the minting
    const issuer = await createIssuer();

    await hyperCoreWrite.sendSpot(issuer, 0, scale(10, 8));
    await hyperCoreWrite.flushActionQueue();

    await issuer.initiateMintRequest(scale(10, 8));
    await hyperCoreWrite.flushActionQueue();

    await issuer.completeMint(users[0]);
    await hyperCoreWrite.flushActionQueue();

    // set up the withdraw
    await wusdc.withdraw(scale(4, 6));
    await hyperCoreWrite.flushActionQueue();

    // the L1 activation fee is taken the first time
    expect(await hyperCore.readSpotBalance(users[0], 0)).deep.eq([
      scale(3, 8),
      0n,
      0n,
    ]);
  });
});
