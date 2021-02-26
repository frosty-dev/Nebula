// large amount of fields creates a heavy load on the server, see updateinfolinks() and addtofield()
#define MAX_FIELDS 50

/*
 * Paper
 * also scraps of paper
 */

/obj/item/paper
	name = "sheet of paper"
	gender = NEUTER
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper"
	item_state = "paper"
	randpixel = 8
	throwforce = 0
	w_class = ITEM_SIZE_TINY
	throw_range = 1
	throw_speed = 1
	layer = ABOVE_OBJ_LAYER
	slot_flags = SLOT_HEAD
	body_parts_covered = SLOT_HEAD
	attack_verb = list("bapped")

	var/info		//What's actually written on the paper.
	var/info_links	//A different version of the paper which includes html links at fields and EOF
	var/stamps		//The (text for the) stamps on the paper.
	var/fields		//Amount of user created fields
	var/free_space = MAX_PAPER_MESSAGE_LEN
	var/list/stamped
	var/list/ico[0]      //Icons and
	var/list/offset_x[0] //offsets stored for later
	var/list/offset_y[0] //usage by the photocopier
	var/rigged = 0
	var/spam_flag = 0
	var/last_modified_ckey
	var/age = 0
	var/list/metadata

	var/const/deffont = "Verdana"
	var/const/signfont = "Times New Roman"
	var/const/crayonfont = "Comic Sans MS"
	var/const/fancyfont = "Segoe Script"

	var/scan_file_type = /datum/computer_file/data/text

/obj/item/paper/Initialize(mapload, text, title, list/md = null)
	. = ..(mapload)
	set_content(text ? text : info, title)
	metadata = md
	if(!mapload)
		SSpersistence.track_value(src, /datum/persistent/paper)

/obj/item/paper/proc/set_content(text,title)
	set waitfor = FALSE
	if(title)
		SetName(title)
	info = html_encode(text)
	info = parsepencode(text)
	update_icon()
	update_space(info)
	updateinfolinks()

/obj/item/paper/on_update_icon()
	if(icon_state == "paper_talisman")
		return
	else if(info)
		icon_state = "paper_words"
	else
		icon_state = "paper"

/obj/item/paper/proc/update_space(var/new_text)
	if(new_text)
		free_space -= length(strip_html_properly(new_text))

/obj/item/paper/examine(mob/user, distance)
	. = ..()
	if(name != "sheet of paper")
		to_chat(user, "It's titled '[name]'.")
	if(distance <= 1)
		show_content(usr)
	else
		to_chat(user, "<span class='notice'>You have to go closer if you want to read it.</span>")

/obj/item/paper/proc/show_content(mob/user, forceshow)
	var/show_info = user.handle_reading_literacy(user, info, FALSE, (forceshow || get_dist(src, user) <= 1))
	if(show_info)
		show_browser(user, "<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY bgcolor='[color]'>[show_info][stamps]</BODY></HTML>", "window=[name]")
		onclose(user, "[name]")

/obj/item/paper/verb/rename()
	set name = "Rename paper"
	set category = "Object"
	set src in usr

	if((MUTATION_CLUMSY in usr.mutations) && prob(50))
		to_chat(usr, "<span class='warning'>You cut yourself on the paper.</span>")
		return
	var/n_name = sanitizeSafe(input(usr, "What would you like to label the paper?", "Paper Labelling", null)  as text, MAX_NAME_LEN)

	// We check loc one level up, so we can rename in clipboards and such. See also: /obj/item/photo/rename()
	if(!n_name || !CanInteract(usr, GLOB.deep_inventory_state))
		return
	n_name = usr.handle_writing_literacy(usr, n_name)
	if(n_name)
		SetName(n_name)
	add_fingerprint(usr)

/obj/item/paper/attack_self(mob/user)
	if(user.a_intent == I_HURT)
		if(icon_state == "scrap")
			user.show_message("<span class='warning'>\The [src] is already crumpled.</span>")
			return
		//crumple dat paper
		info = stars(info,85)
		user.visible_message("\The [user] crumples \the [src] into a ball!")
		icon_state = "scrap"
		return
	user.examinate(src)
	if(rigged && (global.current_holiday?.name == "April Fool's Day"))
		if(spam_flag == 0)
			spam_flag = 1
			playsound(loc, 'sound/items/bikehorn.ogg', 50, 1)
			spawn(20)
				spam_flag = 0

/obj/item/paper/attack_ai(mob/living/silicon/ai/user)
	show_content(user)

/obj/item/paper/attack(mob/living/carbon/M, mob/living/carbon/user)
	if(user.zone_sel.selecting == BP_EYES)
		user.visible_message("<span class='notice'>You show the paper to [M]. </span>", \
			"<span class='notice'> [user] holds up a paper and shows it to [M]. </span>")
		M.examinate(src)

	else if(user.zone_sel.selecting == BP_MOUTH) // lipstick wiping
		if(ishuman(M))
			var/mob/living/carbon/human/H = M
			if(H == user)
				to_chat(user, "<span class='notice'>You wipe off the lipstick with [src].</span>")
				H.lip_style = null
				H.update_body()
			else
				user.visible_message("<span class='warning'>[user] begins to wipe [H]'s lipstick off with \the [src].</span>", \
								 	 "<span class='notice'>You begin to wipe off [H]'s lipstick.</span>")
				if(do_after(user, 10, H) && do_after(H, 10, needhand = 0))	//user needs to keep their active hand, H does not.
					user.visible_message("<span class='notice'>[user] wipes [H]'s lipstick off with \the [src].</span>", \
										 "<span class='notice'>You wipe off [H]'s lipstick.</span>")
					H.lip_style = null
					H.update_body()

/obj/item/paper/proc/addtofield(var/id, var/text, var/links = 0)
	var/locid = 0
	var/laststart = 1
	var/textindex = 1
	while(locid < MAX_FIELDS)
		var/istart = 0
		if(links)
			istart = findtext(info_links, "<span class=\"paper_field\">", laststart)
		else
			istart = findtext(info, "<span class=\"paper_field\">", laststart)

		if(istart==0)
			return // No field found with matching id

		laststart = istart+1
		locid++
		if(locid == id)
			var/iend = 1
			if(links)
				iend = findtext(info_links, "</span>", istart)
			else
				iend = findtext(info, "</span>", istart)

			textindex = iend
			break

	if(links)
		var/before = copytext(info_links, 1, textindex)
		var/after = copytext(info_links, textindex)
		info_links = before + text + after
	else
		var/before = copytext(info, 1, textindex)
		var/after = copytext(info, textindex)
		info = before + text + after
		updateinfolinks()

/obj/item/paper/proc/updateinfolinks()
	info_links = info
	var/i = 0
	for(i=1,i<=fields,i++)
		addtofield(i, "<font face=\"[deffont]\"><A href='?src=\ref[src];write=[i]'>write</A></font>", 1)
	info_links = info_links + "<font face=\"[deffont]\"><A href='?src=\ref[src];write=end'>write</A></font>"


/obj/item/paper/proc/clearpaper()
	info = null
	stamps = null
	free_space = MAX_PAPER_MESSAGE_LEN
	stamped = list()
	overlays.Cut()
	updateinfolinks()
	update_icon()

/obj/item/paper/proc/get_signature(var/obj/item/pen/P, mob/user)
	if(P && istype(P, /obj/item/pen))
		return P.get_signature(user)
	return (user && user.real_name) ? user.real_name : "Anonymous"

/obj/item/paper/proc/parsepencode(t, obj/item/pen/P, mob/user, iscrayon, isfancy)
	if(length(t) == 0)
		return ""

	if(findtext(t, "\[sign\]"))
		t = replacetext(t, "\[sign\]", "<font face=\"[signfont]\"><i>[get_signature(P, user)]</i></font>")

	if(iscrayon) // If it is a crayon, and he still tries to use these, make them empty!
		t = replacetext(t, "\[*\]", "")
		t = replacetext(t, "\[hr\]", "")
		t = replacetext(t, "\[small\]", "")
		t = replacetext(t, "\[/small\]", "")
		t = replacetext(t, "\[list\]", "")
		t = replacetext(t, "\[/list\]", "")
		t = replacetext(t, "\[table\]", "")
		t = replacetext(t, "\[/table\]", "")
		t = replacetext(t, "\[row\]", "")
		t = replacetext(t, "\[cell\]", "")
		t = replacetext(t, "\[logo\]", "")

	if(iscrayon)
		t = "<font face=\"[crayonfont]\" color=[P ? P.colour : "black"]><b>[t]</b></font>"
	else if(isfancy)
		t = "<font face=\"[fancyfont]\" color=[P ? P.colour : "black"]><i>[t]</i></font>"
	else
		t = "<font face=\"[deffont]\" color=[P ? P.colour : "black"]>[t]</font>"

	t = pencode2html(t)

	//Count the fields
	var/laststart = 1
	while(fields < MAX_FIELDS)
		var/i = findtext(t, "<span class=\"paper_field\">", laststart)	//</span>
		if(i==0)
			break
		laststart = i+1
		fields++

	return t


/obj/item/paper/proc/burnpaper(obj/item/flame/P, mob/user)
	var/class = "warning"

	if(P.lit && !user.restrained())
		if(istype(P, /obj/item/flame/lighter/zippo))
			class = "rose"

		user.visible_message("<span class='[class]'>[user] holds \the [P] up to \the [src], it looks like \he's trying to burn it!</span>", \
		"<span class='[class]'>You hold \the [P] up to \the [src], burning it slowly.</span>")

		spawn(20)
			if(get_dist(src, user) < 2 && user.get_active_hand() == P && P.lit)
				user.visible_message("<span class='[class]'>[user] burns right through \the [src], turning it to ash. It flutters through the air before settling on the floor in a heap.</span>", \
				"<span class='[class]'>You burn right through \the [src], turning it to ash. It flutters through the air before settling on the floor in a heap.</span>")

				new /obj/effect/decal/cleanable/ash(get_turf(src))
				qdel(src)

			else
				to_chat(user, "<span class='warning'>You must hold \the [P] steady to burn \the [src].</span>")


/obj/item/paper/Topic(href, href_list)
	..()
	if(!usr || (usr.stat || usr.restrained()))
		return

	if(href_list["write"])
		var/id = href_list["write"]
		//var/t = strip_html_simple(input(usr, "What text do you wish to add to " + (id=="end" ? "the end of the paper" : "field "+id) + "?", "[name]", null),8192) as message

		if(free_space <= 0)
			to_chat(usr, "<span class='info'>There isn't enough space left on \the [src] to write anything.</span>")
			return

		var/obj/item/I = usr.get_active_hand() // Check to see if he still got that darn pen, also check what type of pen
		var/iscrayon = 0
		var/isfancy = 0
		if(!istype(I, /obj/item/pen))
			if(usr.back && istype(usr.back,/obj/item/rig))
				var/obj/item/rig/r = usr.back
				var/obj/item/rig_module/device/pen/m = locate(/obj/item/rig_module/device/pen) in r.installed_modules
				if(!r.offline && m)
					I = m.device
				else
					return
			else
				return
		
		var/obj/item/pen/P = I
		if(!P.active)
			P.toggle()

		if(P.iscrayon)
			iscrayon = TRUE

		if(P.isfancy)
			isfancy = TRUE

		var/t =  sanitize(input("Enter what you want to write:", "Write", null, null) as message, free_space, extra = 0, trim = 0)

		if(!t)
			return

		// if paper is not in usr, then it must be near them, or in a clipboard or folder, which must be in or near usr
		if(src.loc != usr && !src.Adjacent(usr) && !((istype(src.loc, /obj/item/clipboard) || istype(src.loc, /obj/item/folder)) && (src.loc.loc == usr || src.loc.Adjacent(usr)) ) )
			return

		var/last_fields_value = fields

		t = parsepencode(t, I, usr, iscrayon, isfancy) // Encode everything from pencode to html


		if(fields > MAX_FIELDS)
			to_chat(usr, "<span class='warning'>Too many fields. Sorry, you can't do this.</span>")
			fields = last_fields_value
			return

		var/processed_text = usr.handle_writing_literacy(usr, t)

		if(id!="end")
			addtofield(text2num(id), processed_text) // He wants to edit a field, let him.
		else
			info += processed_text // Oh, he wants to edit to the end of the file, let him.
			updateinfolinks()

		last_modified_ckey = usr.ckey

		update_space(t)
		var/processed_info_links = usr.handle_reading_literacy(usr, info_links, TRUE)
		if(processed_info_links)
			show_browser(usr, "<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY bgcolor='[color]'>[processed_info_links][stamps]</BODY></HTML>", "window=[name]") // Update the window
			playsound(src, pick('sound/effects/pen1.ogg','sound/effects/pen2.ogg'), 10)
			update_icon()


/obj/item/paper/attackby(obj/item/P, mob/user)
	..()
	var/clown = 0
	if(user.mind && (user.mind.assigned_role == "Clown"))
		clown = 1

	if(istype(P, /obj/item/tape_roll))
		var/obj/item/tape_roll/tape = P
		tape.stick(src, user)
		return

	if(istype(P, /obj/item/paper) || istype(P, /obj/item/photo))
		if(!can_bundle())
			return
		var/obj/item/paper/other = P
		if(istype(other) && !other.can_bundle())
			return
		if (istype(P, /obj/item/paper/carbon))
			var/obj/item/paper/carbon/C = P
			if (!C.iscopy && !C.copied)
				to_chat(user, "<span class='notice'>Take off the carbon copy first.</span>")
				add_fingerprint(user)
				return
		var/obj/item/paper_bundle/B = new(src.loc)
		if (name != "paper")
			B.SetName(name)
		else if (P.name != "paper" && P.name != "photo")
			B.SetName(P.name)

		if(!user.unEquip(P, B) || !user.unEquip(src, B))
			return
		user.put_in_hands(B)

		to_chat(user, "<span class='notice'>You clip the [P.name] to [(src.name == "paper") ? "the paper" : src.name].</span>")

		B.pages.Add(src)
		B.pages.Add(P)
		B.update_icon()

	else if(istype(P, /obj/item/pen))
		if(icon_state == "scrap")
			to_chat(usr, "<span class='warning'>\The [src] is too crumpled to write on.</span>")
			return

		var/obj/item/pen/robopen/RP = P
		if ( istype(RP) && RP.mode == 2 )
			RP.RenamePaper(user,src)
		else
			var/processed_info_links = user.handle_reading_literacy(user, info_links, length(info))
			if(processed_info_links)
				show_browser(user, "<HTML><HEAD><TITLE>[name]</TITLE></HEAD><BODY bgcolor='[color]'>[processed_info_links][stamps]</BODY></HTML>", "window=[name]")
		return

	else if(istype(P, /obj/item/stamp) || istype(P, /obj/item/clothing/ring/seal))
		if((!in_range(src, usr) && loc != user && !( istype(loc, /obj/item/clipboard) ) && loc.loc != user && user.get_active_hand() != P))
			return

		stamps += (stamps=="" ? "<HR>" : "<BR>") + "<i>This paper has been stamped with the [P.name].</i>"

		var/image/stampoverlay = image('icons/obj/bureaucracy.dmi')
		var/x
		var/y
		if(istype(P, /obj/item/stamp/captain) || istype(P, /obj/item/stamp/boss))
			x = rand(-2, 0)
			y = rand(-1, 2)
		else
			x = rand(-2, 2)
			y = rand(-3, 2)
		offset_x += x
		offset_y += y
		stampoverlay.pixel_x = x
		stampoverlay.pixel_y = y

		if(istype(P, /obj/item/stamp/clown))
			if(!clown)
				to_chat(user, "<span class='notice'>You are totally unable to use the stamp. HONK!</span>")
				return

		if(!ico)
			ico = new
		ico += "paper_[P.icon_state]"
		stampoverlay.icon_state = "paper_[P.icon_state]"

		if(!stamped)
			stamped = new
		stamped += P.type
		overlays += stampoverlay

		playsound(src, 'sound/effects/stamp.ogg', 50, 1)
		to_chat(user, "<span class='notice'>You stamp the paper with your [P.name].</span>")

	else if(istype(P, /obj/item/flame))
		burnpaper(P, user)

	else if(istype(P, /obj/item/paper_bundle))
		if(!can_bundle())
			return
		var/obj/item/paper_bundle/attacking_bundle = P
		attacking_bundle.insert_sheet_at(user, (attacking_bundle.pages.len)+1, src)
		attacking_bundle.update_icon()

	add_fingerprint(user)

/obj/item/paper/proc/can_bundle()
	return TRUE

/obj/item/paper/proc/show_info(var/mob/user)
	return info

//For supply.
/obj/item/paper/manifest
	name = "supply manifest"
	var/order_total = 0
	var/is_copy = 1
/*
 * Premade paper
 */
/obj/item/paper/court
	name = "Judgement"
	info = "For crimes as specified, the offender is sentenced to:<BR>\n<BR>\n"

/obj/item/paper/crumpled
	name = "paper scrap"
	icon_state = "scrap"

/obj/item/paper/crumpled/on_update_icon()
	return

/obj/item/paper/crumpled/bloody
	icon_state = "scrap_bloodied"

/obj/item/paper/aromatherapy_disclaimer
	name = "aromatherapy disclaimer"
	info = "<I>The manufacturer and the retailer make no claims of the contained products' effacy.</I> <BR><BR><B>Use at your own risk.</B>"