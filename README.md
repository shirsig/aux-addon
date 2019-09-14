# aux - WoW Classic (1.13) AddOn

Former Vanilla (1.12) addon - now also available for Classic!

## Core Features

### General
* Completely independent replacement for the Blizzard interface.
* Elegant look stolen from TSM3.
* Many convenient shortcuts.
* Convenient access to the unaltered Blizzard interface.

### Search
* Automatic scanning of all pages for a query.
* Saving of recent and favorite queries.
* History of result listings with internet browser-like interface.
* Advanced search filters which can be combined with logical operators.
* Autocompletion for entering filters.
* Concise listings cleary showing the most important information.
* Sorting by percentage of historical value and unit price.
* Sorting across all scanned pages.
* Quick buying from any page without rescanning everything.
* Real time mode which continuously scans the "newest" (actually longest duration) auctions.

### Post
* Automatic stacking.
* Automatic scanning of existing auctions.
* Concise listing of existing auctions.
* Undercutting of existing auctions by click.
* Concise listing of inventory items excluding the non auctionable.
* Manual exclusion of specific items from the inventory listing.
* Saving post configuration per item.
* Efficient price input inspired by TSM.

### History
* Automatic gathering of historical data from all scans.
* Automatic collection of vendor prices.
* Intricate calculations for a reliable historical value.
* Tooltip with historical value, vendor prices and disenchant value.
* Efficient storage of data.

## Slash Commands
### General
**/aux** (Lists the settings)<br/>
**/aux scan** (Scans the whole auction house. Currently only used for price history. May take about a minute)
**/aux scale _factor_** (Scales the aux GUI by _factor_)<br/>
**/aux ignore owner** (Disables waiting for owner names when scanning. Recommended)<br/>
**/aux post bid** (Adds a bid price listing to the post tab. Requires **/run ReloadUI()** to take effect)<br/>
**/aux crafting cost** (Toggles the crafting price information)<br/>
**/aux post duration _hours_** (Sets the default auction duration to _2_/_8_/_24_ hours)<br/>
### Tooltip
**/aux tooltip value**<br/>
**/aux tooltip daily**<br/>
**/aux tooltip disenchant value**<br/>
**/aux tooltip disenchant distribution**<br/>
**/aux tooltip merchant buy**<br/>
**/aux tooltip merchant sell**<br/>

## Usage
### General
For the auction listings in the search, auctions and bids tabs the following shortcuts are available.
- Double-click on a row with blue colored count to expand it.
- Alt-left-click on the selected row for buyout/cancel.
- Alt-right-click on the selected row for bid/cancel.
- Right-click on a row to start a search for the auctioned item.
- Control-click on a row the show a preview in the wardrobe frame.
- Shift-click on a row to copy the link to the chatframe.
- Left-click on a header to sort.
- Right-click on a header of a price column to switch between unit and stack price.

Furthermore
- Double-click in editboxes will highlight everything.

### Search
- Hitting tab in the search box will accept an autocompletion.
- Dragging inventory items to the search box or alt-clicking them will start a search.
- Alt-clicking item links will start a search.

#### Search Results
![Alt text](http://i.imgur.com/hI6ODqM.png)
- Bid prices for your own active bids are colored in green.
- Bid prices for other auctions with an active bid are colored in orange.

#### Saved Searches
![Alt text](http://i.imgur.com/dICDnxR.png)
- When hovering over an entry the tooltip shows a longer and more nicely formatted version.
- Left-click on an entry will start a search.
- Right-click on an entry will show a menu with various options, including toggling Alert.
- Shift-left-click on an entry will copy a search to the search box.
- Shift-right-click on an entry will add a search to the existing query in the search box.

#### Filter Builder
![Alt text](http://i.imgur.com/8hilZc9.png)
While it is faster to type filters directly into the search box this sub-tab serves as a tutorial to learn how to formulate queries.
The filters on the left side are Blizzard filters which may reduce the number of pages to be scanned and those on the right side are post filters which do not affect the scan time but can be combined with logical operators to formulate very complex filters.
### Post
![Alt text](http://i.imgur.com/otzOT2I.png)
- When entering prices **g**, **s** and **c** denote gold, silver and copper respectively.
- A price value without explicit denotations will count as gold. (e.g., 10.5 = 10g50s)
- Price values can contain decimals. (e.g., 1.5g = 1g50s)
- Right-clicking an item in the inventory listing will start a search.
- Dragging an inventory item to the search box or alt-clicking it will select it in the listing.
- In the listing of bids/buyouts a red price is undercutting stack/unit price.
- Clicking an entry in the in the listings of bids/buyouts of existing auctions will undercut with your bid stack/buyout unit price.
- Double-click in the bids/buyouts listings will also match the stack size.

### Auctions
![Alt text](http://i.imgur.com/6HjaIo2.png)

### Bids
![Alt text](http://i.imgur.com/NOjPKNW.png)

## Search Filters
AddOns do not have any additional Blizzard filters available to them beyond the ones in the default auction house interface, nor do they have any other ways to combine them.
Of course it is possible for an addOn to apply arbitrary filters after the Blizzard query but only the Blizzard query will affect the number of pages to be scanned and thus the time it takes for a scan.
Since the Vanilla API will only let you request a page every 4 seconds having no Blizzard query in your filter can lead to very long scan times.

aux queries are separated by semicolons and always contain exactly one Blizzard query. The Blizzard query may be empty, i.e., all pages are scanned, which can be useful for collecting historical data.
The real time mode only supports empty Blizzard queries.
Semicolons always mean "or", i.e., **q1;q2;q3** means all items matching **q1** or **q2** or **q3** will be listed.

The parts of individual queries are separated by slashes, e.g., **q1p1/q1p2;q2p1/q2p2/q2p3**. All parts either belong to the Blizzard filter or the post processing filter.

Blizzard filters can be created through the form on the left side of the "New Filter" sub-tab of the "Search" tab or typed directly into the search box.
For learning to write queries you can fill in the form, add the query to the search box with the "Add" or "Replace" buttons and inspect the generated output until you feel comfortable typing them out yourself.
For the most part it should be rather intuitive.
The first part is special in that if it doesn't match any specific filter keyword it will be treated as a Blizzard name search. E.g., a query consisting only of **felcloth** would list the items Felcloth, Pattern: Felcloth Hood, Felcloth Bag etc.
Usually you would want to use the **exact** modifier which only matches auctions where the name, apart from case, exactly equals the first part of the query.
**exact** is the only modifier which is part Blizzard and part post filter, though it is mostly treated as a Blizzard filter. **exact** will tailor the Blizzard query as well as possible towards the item searched (level range, item class/subclass/slot, quality ...) and it cannot be used together with Blizzard filters for these properties.

Post processing filters are more flexible.
They are specified using the filter primitives you find on the right side of the "New Filter" sub-tab and can be combined with **and**, **or** and **not** using polish notation (https://en.wikipedia.org/wiki/Polish_notation).
Filter parts other than the first which don't match any specific filter, just like the first part is treated as a Blizzard name filter, are treated as a tooltip filter.
For using a tooltip filter as the first filter part there is an explicit **tooltip** modifier.

Here are some queries I use myself for illustration:

**or/and2/profit/5g/percent/60/and3/bid-profit/5g/bid-percent/60/left/30m**<br/>
This filter will search the whole auction house for auctions either with a buyout price of 5g or more below market value and 60% or less of the market value or a bid price for which the same is true and in addition only 30m or less remaining.

**wrangler's wristbands/exact/or2/and2/+3 agility/+3 stamina/+5 stamina/price/1g**<br/>
This will search for wrangler's wristband with 3/3 monkey or 5 stam suffixes for at most 1g buyout price.

**recipe/usable/not/libram**<br/>
This will scan for usable recipes and exclude those with "libram" in the tooltip (i.e., librams)

**armor/cloth/50/intellect/stamina**<br/>
This will scan the auction house for cloth armor which has a requirement of at least lvl 50 as well both intellect and stamina stats.

## Historical Value

The historical value is a slightly time weighted median of up to 12 saved daily values where a daily value is the minimum unit buyout price for an item scanned over the course of the respective day.