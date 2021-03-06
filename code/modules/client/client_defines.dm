/client
	// * Black magic things *
	parent_type = /datum

	// * Admin things *
	var/datum/admins/holder = null
	var/datum/admins/deadmin_holder = null
	var/adminobs = null
	var/adminhelped = 0
	var/staffwarn = null

	var/default_pixel_x = 0
	var/default_pixel_y = 0

	// * Other things *
	var/datum/preferences/prefs = null

	///datum that controls the displaying and hiding of tooltips
	var/datum/tooltip/tooltips

	/*
	As of byond 512, due to how broken preloading is, preload_rsc MUST be set to 1 at compile time if resource URLs are *not* in use,
	BUT you still want resource preloading enabled (from the server itself). If using resource URLs, it should be set to 0 and
	changed to a URL at runtime (see client_procs.dm for procs that do this automatically). More information about how goofy this broken setting works at
	http://www.byond.com/forum/post/1906517?page=2#comment23727144
	*/
	preload_rsc = 0

	///goonchat chatoutput of the client
	var/datum/chatOutput/chatOutput

	var/fullscreen = FALSE

	// * Sound stuff *
	var/ambience_playing = null
	var/played = 0

	// * Security *
	var/received_irc_pm = -99999

	//IRC admin that spoke with them last.
	var/irc_admin
	var/mute_irc = 0

	// Prevents people from being spammed about multikeying every time their mob changes.
	var/warned_about_multikeying = 0

	// comment out the line below when debugging locally to enable the options & messages menu
	//control_freak = 1

	// * Database related things *

	//So admins know why it isn't working - Used to determine how old the account is - in days.
	var/player_age = "Requires database"

	//So admins know why it isn't working - Used to determine what other accounts previously logged in from this ip
	var/related_accounts_ip = "Requires database"

	//So admins know why it isn't working - Used to determine what other accounts previously logged in from this computer id
	var/related_accounts_cid = "Requires database"
