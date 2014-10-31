# /packages/sencha-task-editor/lib/task-editor.tcl
#
# Copyright (C) 2012 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ----------------------------------------------------------------------
# 
# ---------------------------------------------------------------------

set current_user_id [ad_get_user_id]

# The following variables are expected in the environment
# defined by the calling /tcl/*.tcl libary:
#	project_id

set data_list {}

# project_id may be overwritten by SQLs below
set main_project_id $project_id

# Create a random ID for the task_editor
set task_editor_rand [expr round(rand() * 100000000.0)]
set task_editor_id "task_editor_$task_editor_rand"

# Start and end time for default combo box with time entry options
set time_entry_store_start_hour [parameter::get_from_package_key -package_key "intranet-timesheet2-interval" -parameter TimeEntryStoreStartHour -default "9"]
set time_entry_store_end_hour [parameter::get_from_package_key -package_key "intranet-timesheet2-interval" -parameter TimeEntryStoreEndHour -default "19"]

set please_add_note_required_l10n [lang::message::lookup "" intranet-timesheet2-inverval.Please_add_a_note_required "Please add a note (required)"]

