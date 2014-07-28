# /packages/intranet-timesheet2-interval/tcl/intranet-timesheet2-interval-procs.tcl
#
# Copyright (C) 2014 ]project-open[
# 
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    @author frank.bergmann@project-open.com
}

# ----------------------------------------------------------------------
# Portlets
# ---------------------------------------------------------------------


ad_proc -public im_timesheet_interval_portlet {
    -project_id:required
} {
    Returns a HTML code with a Sencha timesheet entry portlet.
} {
    # Sencha check and permissions
    if {![im_sencha_extjs_installed_p]} { return "" }
    set current_user_id [ad_get_user_id]
    im_project_permissions $current_user_id $project_id view_p read_p write_p admin_p
    if {!$read_p} { return "" }
    if {![im_permission $current_user_id add_hours]} { return "" }
    im_sencha_extjs_load_libraries

    set params [list \
		    [list project_id $project_id] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-timesheet2-interval/lib/timesheet-interval"]
    return [string trim $result]
}



ad_proc -public im_hour_interval_nuke {
    {-current_user_id ""}
    rest_oid
} {
    Delete a hour interval object. 
    This procedure is called from the intranet-rest interface
    after receiving a DELETE HTTP verb
} {
    # hour_interval is not a real object, so we can just delete from the table
    db_dml delete_hour_interval "delete from im_hour_intervals where interval_id = :rest_oid"
    return $rest_oid
}
