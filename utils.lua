StvPages = StvPages or {}

StvPages.bagCache = {}
StvPages.bankCache = {}
StvPages.bagCounts = {}
StvPages.bankCounts = {}
StvPages.inventoryCounts = {}

function colored(text, color)
    return "|" .. color .. text .. "|r"
end

local function rebuildInventoryCounts()
    wipe(StvPages.bagCounts)
    wipe(StvPages.bankCounts)
    wipe(StvPages.inventoryCounts)

    for _bag, items in pairs(StvPages.bagCache) do
        for itemID, count in pairs(items) do
            StvPages.bagCounts[itemID] = (StvPages.bagCounts[itemID] or 0) + count
            StvPages.inventoryCounts[itemID] = (StvPages.inventoryCounts[itemID] or 0) + count
        end
    end

    for _bag, items in pairs(StvPages.bankCache) do
        for itemID, count in pairs(items) do
            StvPages.bankCounts[itemID] = (StvPages.bankCounts[itemID] or 0) + count
            StvPages.inventoryCounts[itemID] = (StvPages.inventoryCounts[itemID] or 0) + count
        end
    end
end

local function getApiBagAndBankCounts(itemID)
    if type(getItemCount) ~= "function" then
        return nil, nil
    end

    local bagCount = getItemCount(itemID, false) or 0
    local totalCount = getItemCount(itemID, true) or bagCount
    if totalCount < bagCount then
        totalCount = bagCount
    end

    return bagCount, totalCount - bagCount
end

function StvPages.updateBag(bagID, isBankBag, skipRebuild)
    local bagItems = {}
    local numSlots = C_Container.GetContainerNumSlots(bagID) or 0

    for slot = 1, numSlots do
        local itemInfo = C_Container.GetContainerItemInfo(bagID, slot)
        local itemLink = C_Container.GetContainerItemLink(bagID, slot)

        if itemInfo and itemLink then
            local itemID = tonumber(itemLink:match("item:(%d+)"))

            if itemID then
                bagItems[itemID] = (bagItems[itemID] or 0) + (itemInfo.stackCount or 1)
            end
        end
    end

    if isBankBag then
        StvPages.bankCache[bagID] = bagItems
    else
        StvPages.bagCache[bagID] = bagItems
    end

    if not skipRebuild then
        rebuildInventoryCounts()
    end
end

function StvPages.updateAllBags()
    wipe(StvPages.bagCache)

    for bagID = 0, NUM_BAG_SLOTS do
        StvPages.updateBag(bagID, false, true)
    end

    rebuildInventoryCounts()
end

function StvPages.updateAllBankBags()
    wipe(StvPages.bankCache)

    if BANK_CONTAINER then
        StvPages.updateBag(BANK_CONTAINER, true, true)
    end

    if NUM_BAG_SLOTS and NUM_BANKBAGSLOTS then
        for bagID = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
            StvPages.updateBag(bagID, true, true)
        end
    end

    rebuildInventoryCounts()
end

function StvPages.getItemCount(itemID)
    return StvPages.getBagItemCount(itemID) + StvPages.getBankItemCount(itemID)
end

function StvPages.getBagItemCount(itemID)
    local cachedBagCount = StvPages.bagCounts[itemID] or 0
    local apiBagCount = select(1, getApiBagAndBankCounts(itemID))

    if type(apiBagCount) == "number" then
        return apiBagCount
    end

    return cachedBagCount
end

function StvPages.getBankItemCount(itemID)
    local cachedBankCount = StvPages.bankCounts[itemID] or 0
    local _apiBagCount, apiBankCount = getApiBagAndBankCounts(itemID)

    if type(apiBankCount) == "number" then
        return apiBankCount
    end

    return cachedBankCount
end

function StvPages.hasItem(itemID)
    return StvPages.getItemCount(itemID) > 0
end

function StvPages.hasItemInBags(itemID)
    return StvPages.getBagItemCount(itemID) > 0
end

function StvPages.hasItemInBank(itemID)
    return StvPages.getBankItemCount(itemID) > 0
end
