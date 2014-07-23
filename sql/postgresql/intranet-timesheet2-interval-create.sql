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
-- Trigger for synchronization between intervals and hours
-- ------------------------------------------------------------

-- Create a new im_hour row for the interval or update 
-- an existing one.
create or replace function im_hour_interval_update_im_hours (integer, integer, date)
returns integer as $body$
DECLARE
	p_user_id		alias for $1;
	p_project_id		alias for $2;
	p_day			alias for $3;

	v_hour_id		integer;
	v_sum_hours		numeric;
	v_sum_notes		varchar;
	row			record;
BEGIN
	-- Check if there is already an im_hours entry
	select h.hour_id into v_hour_id
	from   im_hours h
	where  h.user_id = p_user_id and
	       h.project_id = p_project_id and
	       h.day = p_day;

	-- Create a new entry if there wasnt one before
	IF v_hour_id is null THEN
		v_hour_id := nextval('im_hours_seq');
		RAISE NOTICE 'im_hour_interval_insert_tr: About to insert a new im_hour with ID=%', v_hour_id;
		insert into im_hours (
			hour_id, user_id, project_id, day, hours, note
		) values (
			v_hour_id, p_user_id, p_project_id, p_day, 0, ''
		);
	END IF;

	-- Sum up all interval properties into one hour row
	v_sum_hours := 0.0;
	v_sum_notes := '';
	FOR row IN
		select	*
		from	im_hour_intervals
		where	user_id = p_user_id and
			project_id = p_project_id and
			interval_start::date = p_day
	LOOP
		v_sum_hours := v_sum_hours + coalesce(extract(epoch from row.interval_end - row.interval_start) / 3600.0, 0.0);
		v_sum_notes := v_sum_notes || coalesce(row.note, '') || E'\n';
	END LOOP;

	-- Update the im_hours entry with the sum of the values
	update	im_hours
	set	hours = v_sum_hours, note = v_sum_notes
	where	hour_id = v_hour_id;
	
	return 0;
END;$body$ language 'plpgsql';


create or replace function im_hour_interval_insert_tr ()
returns trigger as $body$
BEGIN
	PERFORM im_hour_interval_update_im_hours (new.user_id, new.project_id, new.interval_start::date);
	return new;
END;$body$ language 'plpgsql';


create or replace function im_hour_interval_update_tr ()
returns trigger as $body$
BEGIN
	PERFORM im_hour_interval_update_im_hours (new.user_id, new.project_id, new.interval_start::date);
	IF new.interval_start::date != old.interval_start::date THEN
		PERFORM im_hour_interval_update_im_hours (old.user_id, old.project_id, old.interval_start::date);
	END IF;
	return new;
END;$body$ language 'plpgsql';


create or replace function im_hour_interval_delete_tr ()
returns trigger as $body$
BEGIN
	PERFORM im_hour_interval_update_im_hours (old.user_id, old.project_id, old.interval_start::date);
	return old;
END;$body$ language 'plpgsql';


create trigger im_hour_interval_insert_tr after insert on im_hour_intervals for each row execute procedure im_hour_interval_insert_tr();
create trigger im_hour_interval_update_tr after update on im_hour_intervals for each row execute procedure im_hour_interval_update_tr();
create trigger im_hour_interval_delete_tr after delete on im_hour_intervals for each row execute procedure im_hour_interval_delete_tr();





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

