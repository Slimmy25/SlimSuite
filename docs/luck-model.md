# Legendary luck prototype

This optional WIP uses the model in the user's supplied graph: rarity weights 60, 25k, 10k², 4k³ and k⁴, with k = 1 + current luck + min(0.30, player level × 0.01) + source bonus. Amulets use a 0.5 source bonus. The panel shows only legendary estimates. The same model is described as approximate in [LuckyOdds' source](https://github.com/cadoky/LuckyOdds/blob/main/LuckyOdds.lua); it is not an authoritative roll API.

The available creator changelog was searched through 0.139.0. Relevant entries include 0.21.0 jewelry luck bonuses, 0.73.0 expanded live run stats, 0.117.0 permanent co-op luck, and 0.121.0 boss-gear bad-luck protection. The latest available notes do not publish a replacement card-rarity formula. Boss-gear protection is a separate roll and is not added to card estimates. Creator patch-note text was left unchanged.

The panel reads AZS_STATS.luck once as the current total. It does not add race, gear or co-op bonuses again. Item stat changes therefore update the estimate without double counting.

“Stonks rising” and “New Nvidia Affair” reflect whether the model's marginal legendary gain over the next two +10 percentage-point luck steps is increasing or decreasing. They do not incorporate purchase costs, build damage lost, source-specific guarantees or an actual return-on-investment model. The small status line explicitly calls this a model estimate. No rare/epic odds or one-in-N claims are shown.
