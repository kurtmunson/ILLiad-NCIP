--About ALMA_NCIP_Client 1.6
--
--Author:  Bill Jones III, SUNY Geneseo, IDS Project, jonesw@geneseo.edu
--Modified by: Tom McNulty, VCU Libraries, tmcnulty@vcu.edu
--Modified by: Kurt Munson, Northwestern University, kmunson@northwestern.edu
--System Addon used for ILLiad to communicate with Alma through NCIP protocol
--
--Description of Registered Event Handlers for ILLiad
--
--BorrowingRequestCheckedInFromLibrary 
--This will trigger whenever a non-cancelled transaction is processed from the Check In From Lending Library 
--batch processing form using the Check In, Check In Scan Now, or Check In Scan Later buttons.
--
--BorrowingRequestCheckedInFromCustomer
--This will trigger whenever an item is processed from the Check Item In batch processing form, 
--regardless of its status (such as if it were cancelled or never picked up by the customer).
--
--LendingRequestCheckOut
--This will trigger whenever a transaction is processed from the Lending Update Stacks Searching form 
--using the Mark Found or Mark Found Scan Now buttons. This will also work on the Lending Processing ribbon
--of the Request form for the Mark Found and Mark Found Scan Now buttons.
--
--LendingRequestCheckIn
--This will trigger whenever a transaction is processed from the Lending Returns batch processing form.
--
--Queue names have a limit of 40 characters (including spaces).


local Settings = {};

--NCIP Responder URL
Settings.NCIP_Responder_URL = GetSetting("NCIP_Responder_URL");

--Change Prefix Settings for Transactions
Settings.Use_Prefixes = GetSetting("Use_Prefixes");
Settings.Prefix_for_LibraryUseOnly = GetSetting("Prefix_for_LibraryUseOnly");
Settings.Prefix_for_RenewablesAllowed = GetSetting("Prefix_for_RenewablesAllowed");
Settings.Prefix_for_LibraryUseOnly_and_RenewablesAllowed = GetSetting("Prefix_for_LibraryUseOnly_and_RenewablesAllowed");

--NCIP Error Status Changes
Settings.BorrowingAcceptItemFailQueue = GetSetting("BorrowingAcceptItemFailQueue");
Settings.BorrowingCheckInItemFailQueue = GetSetting("BorrowingCheckInItemFailQueue");
Settings.LendingCheckOutItemFailQueue = GetSetting("LendingCheckOutItemFailQueue");
Settings.LendingCheckInItemFailQueue = GetSetting("LendingCheckInItemFailQueue");

--acceptItem settings
Settings.acceptItem_from_uniqueAgency_value = GetSetting("acceptItem_from_uniqueAgency_value");
Settings.acceptItem_Transaction_Prefix = GetSetting("checkInItem_Transaction_Prefix");

--checkInItem settings
Settings.checkInItem_EnablePatronBorrowingReturns = GetSetting("EnablePatronBorrowingReturns");
Settings.ApplicationProfileType = GetSetting("ApplicationProfileType");
Settings.checkInItem_Transaction_Prefix = GetSetting("checkInItem_Transaction_Prefix");

--checkOutItem settings
Settings.checkOutItem_RequestIdentifierValue_Prefix = GetSetting("checkOutItem_RequestIdentifierValue_Prefix");

function Init()
	RegisterSystemEventHandler("BorrowingRequestCheckedInFromLibrary", "BorrowingAcceptItem");
	RegisterSystemEventHandler("BorrowingRequestCheckedInFromCustomer", "BorrowingCheckInItem");
	RegisterSystemEventHandler("LendingRequestCheckOut", "LendingCheckOutItem");
	RegisterSystemEventHandler("LendingRequestCheckIn", "LendingCheckInItem");
end

--Borrowing Functions
function BorrowingAcceptItem(transactionProcessedEventArgs)
	LogDebug("BorrowingAcceptItem - start");
	
	if GetFieldValue("Transaction", "RequestType") == "Loan" then
	
	LogDebug("Item Request has been identified as a Loan and not Article - process started.");
	
	luanet.load_assembly("System");
	local ncipAddress = Settings.NCIP_Responder_URL;
	local BAImessage = buildAcceptItem();
	LogDebug("creating BorrowingAcceptItem message[" .. BAImessage .. "]");
	local WebClient = luanet.import_type("System.Net.WebClient");
	local myWebClient = WebClient();
	LogDebug("WebClient Created");
	LogDebug("Adding Header");

	LogDebug("Setting Upload String");
	local BAIresponseArray = myWebClient:UploadString(ncipAddress, BAImessage);
	LogDebug("Upload response was[" .. BAIresponseArray .. "]");
	
	LogDebug("Starting error catch")
	local currentTN = GetFieldValue("Transaction", "TransactionNumber");
	
	if string.find (BAIresponseArray, "Item Not Checked Out") then
	LogDebug("NCIP Error: Item Not Checked Out");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorAcceptItem-NotCheckedOut"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BAIresponseArray});
    SaveDataSource("Transaction");
	
	elseif string.find(BAIresponseArray, "User Authentication Failed") then
	LogDebug("NCIP Error: User Authentication Failed");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorAcceptItem-UserAuthFail"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BAIresponseArray});
    SaveDataSource("Transaction");
	
	--this error came up from non-standard characters in the title (umlauts)
	elseif string.find(BAIresponseArray, "Service is not known") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorAcceptItem-SrvcNotKnown"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BAIresponseArray});
    SaveDataSource("Transaction");	

	elseif string.find(BAIresponseArray, "Problem") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, Settings.BorrowingAcceptItemFailQueue});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BAIresponseArray});
    SaveDataSource("Transaction");
	
	else
	LogDebug("No Problems found in NCIP Response.")
	ExecuteCommand("AddNote", {currentTN, "NCIP Response for BorrowingAcceptItem received successfully"});
    SaveDataSource("Transaction");
	end
	end
end


function BorrowingCheckInItem(transactionProcessedEventArgs)

	LogDebug("BorrowingCheckInItem - start");
	luanet.load_assembly("System");
	local ncipAddress = Settings.NCIP_Responder_URL;
	local BCIImessage = buildCheckInItemBorrowing();
	LogDebug("creating BorrowingCheckInItem message[" .. BCIImessage .. "]");
	local WebClient = luanet.import_type("System.Net.WebClient");
	local myWebClient = WebClient();
	LogDebug("WebClient Created");
	LogDebug("Adding Header");
	myWebClient.Headers:Add("Content-Type", "text/xml; charset=UTF-8");
	LogDebug("Setting Upload String");
	local BCIIresponseArray = myWebClient:UploadString(ncipAddress, BCIImessage);
	LogDebug("Upload response was[" .. BCIIresponseArray .. "]");
	
	LogDebug("Starting error catch")
	local currentTN = GetFieldValue("Transaction", "TransactionNumber");
	
	if string.find(BCIIresponseArray, "Unknown Item") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorCheckIn-UnknownItem"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BCIIresponseArray});
    SaveDataSource("Transaction");
	
	elseif string.find(BCIIresponseArray, "Item Not Checked Out") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, "NCIP Error: BorCheckIn-NotCheckedOut"});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BCIIresponseArray});
    SaveDataSource("Transaction");
	
	elseif string.find(BCIIresponseArray, "Problem") then
	LogDebug("NCIP Error: ReRouting Transaction");
	ExecuteCommand("Route", {currentTN, Settings.BorrowingCheckInItemFailQueue});
	LogDebug("Adding Note to Transaction with NCIP Client Error");
	ExecuteCommand("AddNote", {currentTN, BCIIresponseArray});
    SaveDataSource("Transaction");
	
	else
	LogDebug("No Problems found in NCIP Response.")
	ExecuteCommand("AddNote", {currentTN, "NCIP Response for BorrowingCheckInItem received successfully"});
    SaveDataSource("Transaction");
	end
end





--AcceptItem XML Builder for Borrowing
--sometimes Author fields and Title fields are blank
function buildAcceptItem()
local tn = "";
local dr = tostring(GetFieldValue("Transaction", "DueDate"));
local df = string.match(dr, "%d+\/%d+\/%d+");
local mn, dy, yr = string.match(df, "(%d+)/(%d+)/(%d+)");
local mnt = string.format("%02d",mn);
local dya = string.format("%02d",dy);
local user = GetFieldValue("Transaction", "Username");
if Settings.Use_Prefixes then
	local t = GetFieldValue("Transaction", "TransactionNumber");
	if GetFieldValue("Transaction", "LibraryUseOnly") and GetFieldValue("Transaction", "RenewalsAllowed") then
	    tn = Settings.Prefix_for_LibraryUseOnly_and_RenewablesAllowed .. t;
	end
	if GetFieldValue("Transaction", "LibraryUseOnly") and GetFieldValue("Transaction", "RenewalsAllowed") ~= true then
	    tn = Settings.Prefix_for_LibraryUseOnly .. t;
	end
	if GetFieldValue("Transaction", "RenewalsAllowed") and GetFieldValue("Transaction", "LibraryUseOnly") ~= true then
		tn = Settings.Prefix_for_RenewablesAllowed .. t;
	end
	if GetFieldValue("Transaction", "LibraryUseOnly") ~= true and GetFieldValue("Transaction", "RenewalsAllowed") ~= true then
		tn = Settings.acceptItem_Transaction_Prefix .. t;
	end
else 
	tn = Settings.acceptItem_Transaction_Prefix .. GetFieldValue("Transaction", "TransactionNumber");
end

local author = GetFieldValue("Transaction", "LoanAuthor");
	if author == nil then
		author = "";
	end
	if string.find(author, "&") ~= nil then
		author = string.gsub(author, "&", "and");
	end
local title = GetFieldValue("Transaction", "LoanTitle");
	if title == nil then
		title = "";
	end
	if string.find(title, "&") ~= nil then
		title = string.gsub(title, "&", "and");
	end
	
local pickup_location_full = GetFieldValue("Transaction", "Location");
local sublibraries = assert(io.open(AddonInfo.Directory .. "\\sublibraries.txt", "r"));
local pickup_location = "";
local templine = nil;
	if sublibraries ~= nil then
		for line in sublibraries:lines() do
			if string.find(line, pickup_location_full) ~= nil then
				pickup_location = string.sub(line, line:len() - 2);
				break;
				
			else
				pickup_location = "nothing";
			end
		end
		sublibraries:close();
	end

local m = '';
    m = m .. '<?xml version="1.0" encoding="ISO-8859-1"?>'
	m = m .. '<NCIPMessage xmlns="http://www.niso.org/2008/ncip" version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">'
	m = m .. '<AcceptItem>'
	m = m .. '<InitiationHeader>'
	m = m .. '<FromAgencyId>'
	m = m .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	m = m .. '</FromAgencyId>'
	m = m .. '<ToAgencyId>'
	m = m .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	m = m .. '</ToAgencyId>'
	m = m .. '<ApplicationProfileType>' .. Settings.ApplicationProfileType .. '</ApplicationProfileType>'
	m = m .. '</InitiationHeader>'
	m = m .. '<RequestId>'
	m = m .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	m = m .. '<RequestIdentifierValue>' .. tn .. '</RequestIdentifierValue>'
	m = m .. '</RequestId>'
	m = m .. '<RequestedActionType>Hold For Pickup And Notify</RequestedActionType>'
	m = m .. '<UserId>'
	m = m .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	m = m .. '<UserIdentifierType>Barcode Id</UserIdentifierType>'
	m = m .. '<UserIdentifierValue>' .. user .. '</UserIdentifierValue>'
	m = m .. '</UserId>'
	m = m .. '<ItemId>'
	m = m .. '<ItemIdentifierValue>' .. tn .. '</ItemIdentifierValue>'
	m = m .. '</ItemId>'
	m = m .. '<DateForReturn>' .. yr .. '-' .. mnt .. '-' .. dya .. 'T23:59:00' .. '</DateForReturn>'
  m = m .. '<PickupLocation>' .. pickup_location .. '</PickupLocation>'
	m = m .. '<ItemOptionalFields>'
	m = m .. '<BibliographicDescription>'
	m = m .. '<Author>' .. author .. '</Author>'
	m = m .. '<Title>' .. title .. '</Title>'
	m = m .. '</BibliographicDescription>'
	m = m .. '</ItemOptionalFields>'
	m = m .. '</AcceptItem>'
	m = m .. '</NCIPMessage>'
	return m;
 end

--ReturnedItem XML Builder for Borrowing (Patron Returns)
function buildCheckInItemBorrowing()
local tn = "";
local user = GetFieldValue("Transaction", "Username");
if Settings.Use_Prefixes then
	local t = GetFieldValue("Transaction", "TransactionNumber");
	if GetFieldValue("Transaction", "LibraryUseOnly") and GetFieldValue("Transaction", "RenewalsAllowed") then
	    tn = Settings.Prefix_for_LibraryUseOnly_and_RenewablesAllowed .. t;
	end
	if GetFieldValue("Transaction", "LibraryUseOnly") and GetFieldValue("Transaction", "RenewalsAllowed") ~= true then
	    tn = Settings.Prefix_for_LibraryUseOnly .. t;
	end
	if GetFieldValue("Transaction", "RenewalsAllowed") and GetFieldValue("Transaction", "LibraryUseOnly") ~= true then
		tn = Settings.Prefix_for_RenewablesAllowed .. t;
	end
	if GetFieldValue("Transaction", "LibraryUseOnly") ~= true and GetFieldValue("Transaction", "RenewalsAllowed") ~= true then
		tn = Settings.acceptItem_Transaction_Prefix .. t;
	end
else 
	tn = Settings.acceptItem_Transaction_Prefix .. GetFieldValue("Transaction", "TransactionNumber");
end
	
local cib = '';
    cib = cib .. '<?xml version="1.0" encoding="ISO-8859-1"?>'
	cib = cib .. '<NCIPMessage xmlns="http://www.niso.org/2008/ncip" version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">'
	cib = cib .. '<CheckInItem>'
	cib = cib .. '<InitiationHeader>'
	cib = cib .. '<FromAgencyId>'
	cib = cib .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cib = cib .. '</FromAgencyId>'
	cib = cib .. '<ToAgencyId>'
	cib = cib .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cib = cib .. '</ToAgencyId>'
	cib = cib .. '<ApplicationProfileType>' .. Settings.ApplicationProfileType .. '</ApplicationProfileType>'
	cib = cib .. '</InitiationHeader>'
	cib = cib .. '<UserId>'
	cib = cib .. '<UserIdentifierValue>' .. user .. '</UserIdentifierValue>'
	cib = cib .. '</UserId>'
	cib = cib .. '<ItemId>'
	cib = cib .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cib = cib .. '<ItemIdentifierValue>' .. tn .. '</ItemIdentifierValue>'
	cib = cib .. '</ItemId>'
	cib = cib .. '<RequestId>'
	cib = cib .. '<AgencyId>' .. Settings.acceptItem_from_uniqueAgency_value .. '</AgencyId>'
	cib = cib .. '<RequestIdentifierValue>' .. tn .. '</RequestIdentifierValue>'
	cib = cib .. '</RequestId>'
	cib = cib .. '</CheckInItem>'
	cib = cib .. '</NCIPMessage>'
	return cib;
end

