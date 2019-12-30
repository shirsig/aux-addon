# Changelog
This version is modified from aux-1.0.0

## Updated @20191230
* modified ./aux-addon.lua
    + Use the new default Settings below:
        - scale = 1
        - ignore_owner = false
        - action_shortcuts = false
        - crafting_cost = true
        - post_bid = true
        - post_duration = post.DURATION_8
        - tooltip value = true
        - tooltip merchant_sell = true
        - tooltip merchant_buy = true
        - tooltip daily = true
        - tooltip disenchant_value = false
        - tooltip disenchant_distribution = true
* modified ./tabs/post/core.lua
    - the bid items in the post frame is displayed and sorted using the unit_price.

## Updated @20191228
* modified ./tabs/post/core.lua
    - always return the 'price-1' as the new post price for the selected item record.
* modified ./tabs/post/frame.lua
    - display unit price instead of stack price in post frame.
