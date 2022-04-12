import * as anchor from "@project-serum/anchor";
import fs from 'fs';
import { Connection, Keypair, PublicKey, Transaction } from "@solana/web3.js";
import { GemBank, GemFarm } from './types';
import { findFarmerPDA } from '@gemworks/gem-farm-ts';

class FakeWallet implements anchor.Wallet {
  constructor(readonly payer: Keypair) {}
  async signTransaction(tx: Transaction): Promise<Transaction> {
    tx.partialSign(this.payer);
    return tx;
  }
  async signAllTransactions(txs: Transaction[]): Promise<Transaction[]> {
    return txs.map((t) => {
      t.partialSign(this.payer);
      return t;
    });
  }
  get publicKey(): PublicKey {
    return this.payer.publicKey;
  }
}

const BANK_PROGRAM_PUBLIC_KEY = new PublicKey('bankHHdqMuaaST4qQk6mkzxGeKPHWmqdgor6Gs8r88m');
const FARM_PROGRAM_PUBLIC_KEY = new PublicKey('farmL4xeBFVXJqtfxCzU9b28QACM7E2W2ctT6epAjvE');

const fetchAllGdrPDAs = async (
  connection: Connection,
  wallet: anchor.Wallet,
  vault: PublicKey,
  gemBankProgId: PublicKey
) => {
  const bankIdl = JSON.parse(fs.readFileSync('./gem_bank.json', 'utf8'));
  const provider = new anchor.Provider(
    connection,
    wallet,
    anchor.Provider.defaultOptions()
  );

  const filter = [
    {
      memcmp: {
        offset: 8, //need to prepend 8 bytes for anchor's disc
        bytes: vault.toBase58(),
      },
    },
  ];

  const bankProgram = new anchor.Program<GemBank>(
    bankIdl,
    gemBankProgId,
    provider
  );
  const pdas = await bankProgram.account.gemDepositReceipt.all(filter);
  return pdas;
};

const fetchFarmerAcc = async (
  connection: Connection,
  wallet: anchor.Wallet,
  farmer: PublicKey,
  gemFarmProgId: PublicKey
) => {
  const farmIdl = JSON.parse(fs.readFileSync('./gem_farm.json', 'utf8'));
  const provider = new anchor.Provider(
    connection,
    wallet,
    anchor.Provider.defaultOptions()
  );

  const farmProgram = new anchor.Program<GemFarm>(
    farmIdl,
    gemFarmProgId,
    provider
  );
  return farmProgram.account.farmer.fetch(farmer);
};

const CURSED_MIKES_FARM_ID = new PublicKey('7G1VBHufB3su75rHVK34FWKH84nxqGB55khNDp4tiZAy');
const LONGHARBOR_FARM_ID = new PublicKey('APto75diRogekkBc2u9Gt3SQxtfoHUpPDRBFMjBW4xfi');
const run = async (farmPublicKey: PublicKey, ownerWalletPublicKey: PublicKey) => {
  const leakedKp = Keypair.fromSecretKey(
    Uint8Array.from([
      208, 175, 150, 242, 88, 34, 108, 88, 177, 16, 168, 75, 115, 181, 199,
      242, 120, 4, 78, 75, 19, 227, 13, 215, 184, 108, 226, 53, 111, 149, 179,
      84, 137, 121, 79, 1, 160, 223, 124, 241, 202, 203, 220, 237, 50, 242,
      57, 158, 226, 207, 203, 188, 43, 28, 70, 110, 214, 234, 251, 15, 249,
      157, 62, 80,
    ])
  );
  const fakeWallet = new FakeWallet(leakedKp);
  const rpcNode = process.env.RPC_ENDPOINT || "https://ssc-dao.genesysgo.net";
  const connection = new Connection(rpcNode);
  const [farmerPDA] = await findFarmerPDA(
    farmPublicKey,
    ownerWalletPublicKey,
    //FARM_PROGRAM_PUBLIC_KEY
  );
  const farmerAcc = await fetchFarmerAcc(
    connection,
    fakeWallet,
    farmerPDA,
    FARM_PROGRAM_PUBLIC_KEY
  );
  const foundGDRs = await fetchAllGdrPDAs(
    connection,
    fakeWallet,
    farmerAcc.vault,
    BANK_PROGRAM_PUBLIC_KEY
  );
  console.log(foundGDRs)
};

const CURSED_MIKES_SNAPSHOT = JSON.parse(fs.readFileSync('./86ZWe8iTq5jLCnNyQP8tXhWJgAfLAkzqw5UQUEFPnWXL_holders.json', 'utf8'));

interface Mint {
  owner_wallet: string;
  mint_account: string;
}

let processedOwners: string[] = [];
[CURSED_MIKES_SNAPSHOT[0]].forEach((mint: Mint) => {
  (async () => {
    try {
      if (!processedOwners.includes(mint.owner_wallet)) {
        console.log(`processing: ${mint.owner_wallet} - ${mint.mint_account}`);
        await run(CURSED_MIKES_FARM_ID, new PublicKey(mint.owner_wallet));
        processedOwners = processedOwners.concat([mint.owner_wallet]);
      }
    } catch (err) {
      console.error(err);
    }
  })();
});
