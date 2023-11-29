# Provably Random Raffle Contracts

## About

This code creates a provably random smart contract raffly/sweepstakes.

## What do we want this to do?

1. Users enter by paying for a ticket
   1. Winners of a draw will win all entry fees for the respective draw.
2. After X period of time, draw automatically & programmatically picks a winner. 
   1. Done using Chainlink VRF (for randomness) & Automation (for time-based trigger) to do this. 
   
## Tests:

Write Deploy scripts
Want everything to work on 
   1. Local chain
   2. forked testnet
   3. forked mainnet