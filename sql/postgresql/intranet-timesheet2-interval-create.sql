-- /packages/intranet-timesheet2-interval/sql/postgres/intranet-timesheet2-interval-create.sql
--
-- Copyright (C) 2014 ]project-open[
--
-- @author      frank.bergmann@project-open.com


------------------------------------------------------------
-- Interval Hours
--
-- Start-Stop logging for hours


-- Create a fake object type, because im_hour_interval does not
-- "reference" acs_objects.
select acs_object_type__create_type (
	'im_hour_interval',			-- object_type
	'Timesheet Interval Hour',		-- pretty_name
	'Timesheet Interval Hour',		-- pretty_plural
	'acs_object',				-- supertype
	'im_hour_intervals',			-- table_name
	'interval_id',				-- id_column
	null,					-- package_name
	'f',					-- abstract_p
	null,					-- type_extension_table
	'im_hour_interval__name'		-- name_method
);

update acs_object_types set
	status_type_table = null,
	status_column = null,
	type_column = null
where object_type = 'im_hour_interval';




-- Sequence to create fake object_ids for im_hour_intervals
create sequence im_hour_intervals_seq;

create table im_hour_intervals (
	interval_id		integer 
				default nextval('im_hour_intervals_seq')
				constraint im_hour_intervals_pk
				primary key,
	user_id			integer 
				constraint im_hour_intervals_user_id_nn
				not null 
				constraint im_hour_intervals_user_id_fk
				references users,
	project_id		integer 
				constraint im_hour_intervals_project_id_nn
				not null 
				constraint im_hour_intervals_project_id_fk
				references im_projects,
	interval_start		timestamptz
				constraint im_hour_intervals_interval_start_nn
				not null,
	interval_end		timestamptz
				constraint im_hour_intervals_interval_end_nn
				not null,
	material_id		integer
				constraint im_hour_intervals_material_fk
				references im_materials,
	activity_id		integer
				constraint im_hour_intervals_activity_fk
				references im_categories,
	note			text,
	internal_note		text
);

-- Unique constraint to avoid that you can add two identical rows
alter table im_hour_intervals
add constraint im_hour_intervals_unique unique (user_id, project_id, interval_start, interval_end);

create index im_hour_intervals_project_id_idx on im_hour_intervals(project_id);
create index im_hour_intervals_user_id_idx on im_hour_intervals(user_id);
create index im_hour_intervals_interval_start_idx on im_hour_intervals(interval_start);





-- ------------------------------------------------------------
-- Portlet
-- ------------------------------------------------------------

SELECT im_component_plugin__new (
	null,					-- plugin_id
	'im_component_plugin',			-- object_type
	now(),					-- creation_date
	null,					-- creation_user
	null,					-- creation_ip
	null,					-- context_id
	'Timesheet Interval',			-- plugin_name
	'intranet-timesheet2-interval',		-- package_name
	'top',					-- location
	'/intranet/projects/view',		-- page_url
	null,					-- view_name
	30,					-- sort_order
	'im_timesheet_interval_portlet -project_id $project_id'
);




-- ------------------------------------------------------------
-- Resource leveling editor
-- ------------------------------------------------------------

SELECT im_menu__new (
	null,						-- p_menu_id
	'im_menu',					-- object_type
	now(),						-- creation_date
	null,						-- creation_user
	null,						-- creation_ip
	null,						-- context_id
	'sencha-task-editor',				-- package_name
	'resource_leveling_editor',			-- label
	'Resource Leveling Editor',			-- name
	'/sencha-task-editor/resource-leveling-editor/resource-leveling-editor', -- url
	60,						-- sort_order
	(select menu_id from im_menus where label = 'resource_management'), -- parent_menu_id
	null						-- p_visible_tcl
);


SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'resource_leveling_editor'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);

