# ILLiad-NCIP
ILLiad Alma NCIP Addon
ILLiad/Alma NCIP Addon
History, Functionality, Configuration, Use, Other Considerations

History:

This ILLiad System Addon is based upon the NCIP Addon Bill Jones at the IDS Project created for Harvard to link ILLiad and Aleph together. Tom McNulty of VCU worked with Moshe Shechter at Ex Libris and Shawn Styer at Atlas Systems to modify it to work with Alma. Chen Mackfeld at ExLibris worked with Kurt Munson at Northwestern to configure it after the June 2015 Alma release. Staff from Atlas Systems working with Northwestern made further modifications so that it will work with multiple Organization Unit Names in Alma and associate these with multiple NVTGCs or sites in ILLiad. Lender due dates are also supported in this configuration. This version of the addon also handles longer barcodes than the Harvard and VCU versions. These instructions are for situations where individual libraries are configured as resource sharing ones in Alma with locations under a fulfillment unit rather than situations where the default resource sharing library is used.

Functionality:

The Addon sends four NCIP messages from ILLiad to Alma. It handles creating incoming borrowing request item records and the associated patron hold, deleting the record when the borrowing item is returned, outgoing lending request are moved to the Resource Sharing Library and returned lending items are restored to their permanent location.

Notes are written into every transaction showing successful responses: “NCIP Response for [Process] received successfully” or when there is an NCIP error the Note contains the NCIP response. The ILLiad Client Log files will contain any errors with the processing of request via NCIP. Thus functionality can be confirmed this way.

Borrowing
When an item is received, i.e., the ILLiad “Check in from Lending Library” function is used, the Addon builds and sends an NCIP Accept Item message to Alma. This creates a brief record for the item where the barcode in Alma is the ILLiad Transaction Number. The item record is located in the Resource Sharing Library associated with a Circulation Desk, a hold is placed on that item for the Patron and the due date is set based upon the lending library’s due date from ILLiad. Thus, the ILL item can be circulated in Alma, displays in the patron’s Primo account and can only be checked out to the patron who requested it. NOTE: ILLiad and Alma must share a common and identical user identifier (Id number, Barcode, etc.) for this to work. This version of the Addon uses the value in the UserName field of the Transactions table in ILLiad to match to the Primary Identifier field in Alma. If a record and hold are successfully created, the Addon adds a note to the ILLiad transaction stating this. If there is an error, the ILLiad request is routed to an error queue and the NCIP error message is written to a note for that transaction.

When a Borrowing item is returned, i.e., the ILLiad “Check In” function is used, the Addon builds and sends an NCIP Check In Item Borrowing message which deletes the brief record and discharges it from the patron’s record. If a record and hold are successfully created, the Addon adds a note to the ILLiad transaction stating this. If there is an error, the ILLiad request is routed to an error queue and the NCIP message is written to a note for that transaction.

Lending
When Updating Stacks Searching, clicking the Mark Found button causes the Addon to send a Lending Check Out Item NCIP message to Alma and the item will be moved to the Resource Sharing Library associated with that Library’s Circulation Desk in Alma. NOTE: NCIP functions by barcode only so you will need to scan in and store the item barcode in an ILLiad field within that transaction. This version of the Addon is designed to use the ItemInfo3 field from ILLiad. If you wish to use a different field, you will need to edit the Addon lua code to use a different field name instead. When an item is successfully relocated, the Addon adds a note to the ILLiad transaction stating this. If there is an error, the ILLiad request is routed to an error queue and the NCIP error message is written to a note for that transaction.

When an item is returned, i.e., the Lending Returns function is used in ILLiad, the Addon sends an NCIP Check In Item Lending message to Alma and the item is returned to its permanent location or routed if needed. When an item is successfully relocated, the Addon adds a note to the ILLiad transaction stating this. If there is an error, the ILLiad request is routed to an error queue and the NCIP error message is written to a note for that transaction.

System Configuration:

ILLiad Configuration

This is a system addon, thus it must be installed and configured on every machine that will communicate with Alma via NCIP. Information on installing and managing Addons is here: https://prometheus.atlas-sys.com/display/ILLiadAddons/Installing+Addons System Addons are handled and configured like Client Addons, not Server Addons. 

You will need the ALMA_NCIP.lua file and the Config.xml files in a folder named ALMA_NCIP within your Addons folder where ILLiad is installed on your machine. If you have multiple pick up locations, i.e., Sites or multiple NVTGCs defined in ILLiad, you will also need a file named sublibraries.txt with each of your Alma Organization Unit Names and its associated ILLiad NVTGC in that order separated by a comma as show below.

MAIN,INU
LAW,INL

The following fields will need to be filled out for the Addon to work. These are configured in the ILLiad client under system.

NCIP_Responder_URL is your Alma server with /view/NCIPServlet appended to the URL. For example: na02.alma.exlibrisgroup.com/view/NCIPServlet

acceptItem_from_uniqueAgency_value is your Institutional Code in Alma. For example 007Bond_INST

ApplicationProfileType is the code for the Resource Sharing Partner you have configured in Alma. For examples, ILLiad

BorrowingAcceptItemFailQueue this is the name of the queue where ILLiad transactions for which a brief record and patron hold could not be created in Alma are placed.

BorrowingCheckInItemFailQueue this is the name of the queue where ILLiad transactions are placed when a borrowing loan is returned but the Item record is not deleted from Alma.

LendingCheckOutItemFailQueue This is the name of the queue where items that were not moved to the Resource Sharing Library are placed.

LendingCheckInItemFailQueue This queue is where returned lending items that could not be moved from the Resource Sharing Library go.

EnablePatronBorrowingReturns This check box determines if returning an item in ILLiad also deletes the Alma brief record and discharges the item from the patron’s account. It should always be checked.

Use_Prefixes This setting determines if the Transaction Number printed on the ILLiad label as a barcode contained additional information about the transaction, like Library Use Only. NOTE: Adding this information will render the barcode unscanable. It is not recommended for use.

Alma Configuration:

Configuration in Alma is a three part process. First, an Organization Unit Name level library is defined as being a Resource Sharing Library one checking the using the check box under Resource Sharing Information. Second, a Fulfillment Unit associated with that library is configured for use by resource sharing requests with two Fulfillment Unit Locations: one for borrowing and one for lending requests. Only the default loan rule is applied. Third, Resource Sharing Partners are defined under Resource Sharing.

1)	Configure the library.Under General Configuration, choose configuration. Under General, choose Libraries and select Add a Library or Edit Library Information. Choose the tab for libraries, select the library you wish to edit. Under Resource Sharing Information, check the Is Resource Sharing Library box. Under Lending Set up, choose a Default Location of Lending Resource Sharing Requests.

2)	Configure the Fulfillment unit. Under Fulfillment Configuration, choose the Configuration menu and select the library you wish to configure the Fulfillment Unit for by choosing that library from the “You are Configuring” dropdown menu. Under the Physical Fulfillment area, click Fulfillment Units. Click the Add Fulfillment Unit button. Name the unit, assign it a code, and set the On Shelf Request Policy to “No Requesting from available holding”. Open the Unit and click on the Fulfillment Unit Locations tab. Add a borrowing and a lending location each and make their Location type “Open”. Under the Fulfillment Unit Rules tab, choose Rule Type of “loan” and apply the Default Loan rule

3)	Configure the partner. Under Resource Sharing in Alma, choose Partners.

Choose Add Partner, 

Under General Information, you will need to add:
1)	A code name, 
2)	A name for the service
3)	Choose ILLiad from the dropdown menu for System Type,
4)	Check the Supports Borrowing checkbox to use NCIP for Borrowing.
5)	Check the Supports Lending checkbox to use NCIP for Lending.
6)	Change the Status to Active.
NOTE: No other configuration is needed on this page.

Click the Parameters Tab

Under General Information:
1)	Select a Value for the User identifier type. This must match the value in the 
2)	The Request Pushing Method should be set to Link using the radio button.
3)	Set the Default library owner to the library associated with the NVTGC/OCLC symbol in ILLiad.

Under Request Item:
1)	Choose OCLC Number from the dropdown for Bibliographic record ID type

Under Check-Out Item:
1)	Set the Default Location to Lending Resource Sharing Requests
2)	Set the Default item Policy to Normal (not Listed)

Under Accept Item: 
1)	Set Default Location to Borrowing Resource Sharing Requests 
2)	Set your Default pick up library 
3)	Click the Automatic Receive check box
4)	Choose a Receive Desk, this should be the circulat9ion desk associated with ILL pickups.

Use:

The Addon is a system one so it runs in the background when items are checked in from the lending library or updated to returned on the Borrowing side. Thus, the steps in ILLiad processing are identical to situations where the Addon is not installed save adding the item barcode into a fillable lending request before marking it found. Only where there is an NCIP error does processing change. If a label does not print or a return slip does not print, check the transaction number to see if there was an NCIP error and the transaction was placed in the error queue. Review the error and reprocess the request in ILLiad as if it was new for borrowing receives. Borrowing returns in the error queue should be discharged in Alma to discharge the item from the patron and to remove the temporary item record. Move the ILLiad request to Awaiting Return Label Printing so it can be returned to its owning library.

On the Lending side when items are updated to shipped, scan the item Barcode into the Item Info 3 field and click the Mark Found button to move the item to the Lending Resource Sharing Location in Alma. On return, just do lending returns as normal. If an item goes into the error queue in ILLiad upon Lending return, just discharge it in Alma and manually update the record in ILLiad by moving it to the Request Finished queue. 

Other Considerations:

Patron notifications

Both ILLiad and Alma are designed to send item availability notices, courtesy reminders and overdue notices. You will need to choose which system you want to send the notices and disable the notices for resource sharing request in the other system. Northwestern chose to use ILLiad for notifications because we batch process requests upon receipt from the lending library and also because of our branches. All the notifications such as “Ful Place On Hold Shelf Letter” had a line:
<xsl:if test="notification_data/phys_item_display/location_name = 'Borrowing Resource Sharing Requests'">
    <xsl:message terminate="yes">this is an ill item!</xsl:message>
 </xsl:if>
So that these notifications were not send for items received via NCIP. This effectively kills the letter so it is not sent.

ILLiad statuses and webpage status masking

To make ILLiad Borrowing Returns processing work the way ILLiad is designed to work, we wrote an ILLiad routing rule to automatically update all received items to “Checked out to Customer” status in ILLiad when the emails were sent. Using Display Statuses in ILLiad, we masked this status from patron and displayed a “Check your NUsearch.account for status” message instead.

Updated 4/12/2016
