#define HIJACK_APC_MAX_AMOUNT 4

/obj/item/implant/hijack
	name = "hijack implant"
	desc = "Allows you to control the machinery in a room by hacking into the APC."
	actions_types = list(/datum/action/item_action/hands_free/activate, /datum/action/item_action/removeAPCs, /datum/action/item_action/accessAPCs, /datum/action/item_action/stealthmodetoggle)
	activated = 1
	var/toggled = FALSE
	icon_state = "hijack"
	var/eye_color
	var/stealthmode = FALSE
	var/stealthcooldown = 0

/obj/item/implant/hijack/activate()
	. = ..()
	toggled = !toggled
	imp_in.click_intercept = toggled ? src : null
	imp_in.siliconaccesstoggle = toggled ? TRUE : FALSE
	to_chat(imp_in,"<span class='notice'>You turn [toggled ? "on" : "off"] [src]'s silicon interactions.</span>")
	toggle_eyes(toggled && !stealthmode)

/obj/item/implant/hijack/proc/toggle_eyes(on)
	if (!ishuman(imp_in))
		return
	var/mob/living/carbon/human/H = imp_in
	H.eye_color = on ? "ff0" : eye_color
	H.dna.update_ui_block(DNA_EYE_COLOR_BLOCK)
	H.update_body()

/obj/item/implant/hijack/implant(mob/living/target, mob/user, silent = FALSE)
	if(..())
		ADD_TRAIT(target, TRAIT_HIJACKER, "implant")
		if (ishuman(target))
			var/mob/living/carbon/human/H = target
			eye_color = H.eye_color
		return TRUE

/obj/item/implant/hijack/removed(mob/target, silent = FALSE, special = 0)
	if(..())
		REMOVE_TRAIT(target, TRAIT_HIJACKER, "implant")
		for (var/area/area in imp_in.siliconaccessareas)
			imp_in.toggleSiliconAccessArea(area)
			var/obj/machinery/power/apc/apc = area.get_apc()
			if (apc)
				apc.hijacker = null
				apc.set_hijacked_lighting()
				apc.update_icon()
		if (ishuman(target))
			var/mob/living/carbon/human/H = target
			H.eye_color = eye_color
		return TRUE

/obj/item/implant/hijack/proc/InterceptClickOn(mob/living/user,params,atom/object)
	if (user.get_active_held_item() || isitem(object) || !toggled || user.incapacitated())
		return
	if (stealthmode == FALSE && istype(object,/obj/machinery/power/apc) && !user.CanReach(object))
		if (hijack_remotely(object))
			return
	if (stealthmode && !user.CanReach(object))
		return
	if (!object.hasSiliconAccessInArea(imp_in))
		return
	var/list/modifiers = params2list(params)
	imp_in.face_atom(object)
	if (modifiers["shift"] && modifiers["ctrl"])
		object.AICtrlShiftClick(imp_in)
		return TRUE
	if (modifiers["shift"])
		object.AIShiftClick(imp_in)
		return TRUE
	if (modifiers["ctrl"])
		object.AICtrlClick(imp_in)
		return TRUE
	if (modifiers["alt"])
		object.AIAltClick(imp_in)
		return TRUE
	object.attack_ai(imp_in)
	return TRUE

/obj/item/implant/hijack/proc/hijack_remotely(obj/machinery/power/apc/apc)
	if (apc.hijacker)
		return FALSE //can't remotely hijack an already hijacked APC
	to_chat(imp_in, "<span class='notice'>Establishing remote connection with APC.</span>")
	if (!do_after(imp_in, 4 SECONDS,target=apc))
		to_chat(imp_in, "<span class='warning'>Aborting.</span>")
		return TRUE
	imp_in.light_power = 2
	imp_in.light_range = 2
	imp_in.light_color = COLOR_YELLOW
	imp_in.update_light()
	imp_in.visible_message("<span class='warning'>[imp_in] starts glowing a with a hollow yellow light!</span>")
	to_chat(imp_in, "<span class='notice'>Beginning hijack of APC.</span>")
	if (do_after(imp_in, 21 SECONDS,target=apc))
		apc.hijacker = imp_in
		stealthmode = FALSE
		apc.set_hijacked_lighting()
		imp_in.toggleSiliconAccessArea(apc.area)
		apc.update_icon()
		stealthcooldown = world.time + 3 MINUTES
		toggle_eyes(TRUE)
	else
		to_chat(imp_in, "<span class='warning'>Aborting.</span>")
	imp_in.light_power = 0
	imp_in.light_range = 0
	imp_in.light_color = COLOR_YELLOW
	imp_in.update_light()
	return TRUE