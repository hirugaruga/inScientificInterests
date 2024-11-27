local VERSION_8_3 = 6
local POSTING_HISTORY_DB_VERSION = 1
local VENDOR_PRICE_CACHE_DB_VERSION = 1
local SHOPPING_LISTS_VERSION = 1

function Auctionator.Variables.Initialize()
  Auctionator.Variables.InitializeSavedState()

  Auctionator.Config.Initialize()

  Auctionator.State.CurrentVersion = GetAddOnMetadata("Auctionator", "Version")
  AUCTIONATOR_STATE_CURRENT_VERSION = Auctionator.State.CurrentVersion

  Auctionator.Variables.InitializeDatabase()
  Auctionator.Variables.InitializeShoppingLists()
  Auctionator.Variables.InitializePostingHistory()
  Auctionator.Variables.InitializeVendorPriceCache()

  Auctionator.State.Loaded = true
end

function Auctionator.Variables.InitializeSavedState()
  if AUCTIONATOR_SAVEDVARS == nil then
    AUCTIONATOR_SAVEDVARS = {}
  end
  Auctionator.SavedState = AUCTIONATOR_SAVEDVARS
end

-- All "realms" that are connected together use the same AH database, this
-- determines which database is in use.
function Auctionator.Variables.GetConnectedRealmRoot()
  local currentRealm = GetRealmName()
  local connections = {} -- TODO: GetAutoCompleteRealms()

  -- We sort so that we always get the same first realm to use for the database
  table.sort(connections)

  if connections[1] ~= nil then
    -- Case where we are on a connected realm
    return connections[1]
  else
    -- We are not on a connected realm
    return currentRealm
  end
end

-- Attempt to import from other connected realms (this may happen if another
-- realm was connected or the databases are not currently shared)
--
-- Assumes rootRealm has no active database
local function ImportFromConnectedRealm(rootRealm)
  local connections = {} -- TODO: GetAutoCompleteRealms()

  if #connections == 0 then
    return false
  end

  for _, altRealm in ipairs(connections) do

    if AUCTIONATOR_PRICE_DATABASE[altRealm] ~= nil then

      AUCTIONATOR_PRICE_DATABASE[rootRealm] = AUCTIONATOR_PRICE_DATABASE[altRealm]
      -- Remove old database (no longer needed)
      AUCTIONATOR_PRICE_DATABASE[altRealm] = nil
      return true
    end
  end

  return false
end

function Auctionator.Variables.InitializeDatabase()
  Auctionator.Debug.Message("Auctionator.Database.Initialize()")
  -- Auctionator.Utilities.TablePrint(AUCTIONATOR_PRICE_DATABASE, "AUCTIONATOR_PRICE_DATABASE")

  -- First time users need the price database initialized
  if AUCTIONATOR_PRICE_DATABASE == nil then
    AUCTIONATOR_PRICE_DATABASE = {
      ["__dbversion"] = VERSION_8_3
    }
  end

  -- If we changed how we record item info we need to reset the DB
  if AUCTIONATOR_PRICE_DATABASE["__dbversion"] ~= VERSION_8_3 then
    AUCTIONATOR_PRICE_DATABASE = {
      ["__dbversion"] = VERSION_8_3
    }
  end

  local realm = Auctionator.Variables.GetConnectedRealmRoot()

  -- Check for current realm and initialize if not present
  if AUCTIONATOR_PRICE_DATABASE[realm] == nil then
    if not ImportFromConnectedRealm(realm) then
      AUCTIONATOR_PRICE_DATABASE[realm] = {}
    end
  end

  Auctionator.Database = CreateAndInitFromMixin(Auctionator.DatabaseMixin, AUCTIONATOR_PRICE_DATABASE[realm])
  Auctionator.Database:Prune()
end

function Auctionator.Variables.InitializePostingHistory()
  Auctionator.Debug.Message("Auctionator.Variables.InitializePostingHistory()")

  if AUCTIONATOR_POSTING_HISTORY == nil  or
     AUCTIONATOR_POSTING_HISTORY["__dbversion"] ~= POSTING_HISTORY_DB_VERSION then
    AUCTIONATOR_POSTING_HISTORY = {
      ["__dbversion"] = POSTING_HISTORY_DB_VERSION
    }
  end

  Auctionator.PostingHistory = CreateAndInitFromMixin(Auctionator.PostingHistoryMixin, AUCTIONATOR_POSTING_HISTORY)
end

local function ModernizeShopingLists()
  if not Auctionator.SavedState.ShoppingListsVersion then
    for _, list in ipairs(AUCTIONATOR_SHOPPING_LISTS) do
      if type(list.items) == "table" then
        for index, item in ipairs(list.items) do
          if type(item) == "string" then
            local s, e = string.find(strlower(item), "изначальная тьма", 1, true)
            if s and e then
              list.items[index] = strconcat(string.sub(item, 1, s - 1), "Изначальная тень", string.sub(item, e + 1))
            end
          end
        end
      end
    end
  end
  Auctionator.SavedState.ShoppingListsVersion = SHOPPING_LISTS_VERSION
end

function Auctionator.Variables.InitializeShoppingLists()
  if AUCTIONATOR_SHOPPING_LISTS == nil then
    AUCTIONATOR_SHOPPING_LISTS = {}
  else
    if Auctionator.SavedState.ShoppingListsVersion == nil or
     Auctionator.SavedState.ShoppingListsVersion ~= SHOPPING_LISTS_VERSION then
      ModernizeShopingLists()
    end
  end

  Auctionator.ShoppingLists.Lists = AUCTIONATOR_SHOPPING_LISTS
  Auctionator.ShoppingLists.Prune()
  Auctionator.ShoppingLists.Sort()
  AUCTIONATOR_SHOPPING_LISTS = Auctionator.ShoppingLists.Lists
end

function Auctionator.Variables.InitializeVendorPriceCache()
  Auctionator.Debug.Message("Auctionator.Variables.InitializeVendorPriceCache()")

  if AUCTIONATOR_VENDOR_PRICE_CACHE == nil  or
     AUCTIONATOR_VENDOR_PRICE_CACHE["__dbversion"] ~= VENDOR_PRICE_CACHE_DB_VERSION then
    AUCTIONATOR_VENDOR_PRICE_CACHE = {
      ["__dbversion"] = VENDOR_PRICE_CACHE_DB_VERSION
    }
  end
end
