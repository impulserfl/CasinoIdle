# tools

## verify_balance.py

Re-derives every minigame's return-to-player from the payout tables **as
actually written in the `.gd` files**, and asserts they match the `base_rtp` and
`LOSS_RATE` constants each script declares.

```
python3 tools/verify_balance.py
```

This is not decorative. `Minigame.fortune_refund_chance()` sizes the Card
Counter / Loaded Dice stake refund from `base_rtp` and the game's loss rate, so
if someone edits a payout table without updating those constants the upgrade is
silently mis-priced — and in the worst case a game creeps to or past 100% RTP,
which would make auto-play an infinite money loop.

The script also asserts that with **every** RTP upgrade maxed, all four games
stay strictly below 1.0 RTP.

Slots and roulette are enumerated exhaustively; scratch cards are enumerated
exactly over all 2,002 ways 9 cells can fall across 6 symbols.
