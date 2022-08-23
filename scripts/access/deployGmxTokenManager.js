const { deployContract, contractAt, writeTmpAddresses, sendTxn } = require("../shared/helpers")

async function main() {
  const tokenManager = await deployContract("TokenManager", [3], "TokenManager")

  const signers = [
    "0x2beEcacFBBfaCd04BE3b9b463D7C097Cd922F4E3", // CantoSpider
    "0xFc149d251fBdB3020a5B52c1660108e777C6061f", // CantoRaptor
    "0x347A1B1eF81aCD74740F6e073577347a8d5Ff107", // CantoSoldier
  ]

  await sendTxn(tokenManager.initialize(signers), "tokenManager.initialize")
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
